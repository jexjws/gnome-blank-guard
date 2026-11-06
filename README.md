# gnome-blank-guard

**熄屏后，只有电源键能把屏幕点亮。**

A small daemon for **Arch Linux + GNOME (Wayland / Mutter)** that keeps a blanked
screen dark: pointer jitter, a brushed touchpad, a key press or an incoming
notification banner can no longer turn the display back on. Only the physical
power button wakes it.

---

## 它解决什么问题

GNOME 熄灭屏幕（Screen Blanking / DPMS Off）之后：

1. **鼠标/触摸板一碰就亮** — Mutter 把任意指针位移都当成「用户回来了」，桌子轻微震动产生的 1px 位移就足以点亮屏幕，而 GNOME 没有提供任何开关。
2. **来消息也会亮** — GNOME Shell 在显示通知横幅时会唤醒熄屏的显示器（上游 issue [gnome-shell#5885](https://gitlab.gnome.org/GNOME/gnome-shell/-/work_items/5885)），QQ/邮件/IM 消息会让屏幕周期性亮起。

`gnome-blank-guard` 把这两个来源都掐掉，只保留电源键作为唯一唤醒方式。

> 注意：本工具针对的是**「系统保持开机、仅关闭显示器」**的场景（后台服务继续运行）。
> 真正的 ACPI 睡眠/挂起（suspend）是另一套机制，需要用内核的 `power/wakeup` 来禁用设备唤醒。

## 工作原理

| 机制 | 说明 |
|---|---|
| 独占抓取输入设备 | 熄屏瞬间对所有鼠标、触摸板、键盘执行 `ioctl(EVIOCGRAB, 1)`，事件被内核直接路由给本进程，合成器收不到任何输入，**晃动鼠标/滑动触摸板完全无效**。 |
| 临时勿扰模式 | 熄屏期间把 `org.gnome.desktop.notifications show-banners` 置为 `false`，通知不再弹横幅，也就不会唤醒屏幕；唤醒后精确还原原值，并把原值落盘到 `~/.cache/gnome-blank-guard/notif-state`，防止进程被 SIGKILL 后勿扰模式永久残留。 |
| 电源键唤醒 | 熄屏时电源键设备也被独占，因此 GNOME 不会把这次按键当成「关机/挂起」；守护进程解析 `KEY_POWER` 后释放所有抓取，并通过 D-Bus 把 Mutter 的 `DisplayConfig.PowerSaveMode` 置回 `0` 点亮屏幕。 |
| 兜底重新熄屏 | 万一还有别的东西（未被抓取的设备、强制唤醒的程序）点亮了屏幕，0.7 秒后自动重新熄灭。 |

## 环境要求

- Arch Linux（其实任何带 GNOME + systemd 的发行版都行）
- GNOME 桌面，**Wayland 会话**（Mutter 提供 `org.gnome.Mutter.DisplayConfig`）
- `python` + `python-gobject`（Arch 包名，提供 `gi`/`Gio`/`GLib`）
- `systemd`

```bash
sudo pacman -S --needed python python-gobject
```

## 安装

```bash
git clone https://github.com/jexjws/gnome-blank-guard.git
cd gnome-blank-guard
sudo ./install.sh            # 默认给 $SUDO_USER 安装
# 或显式指定用户：
sudo ./install.sh youruser
```

安装脚本会：

1. 把守护进程装到 `/usr/local/bin/gnome-blank-guard`
2. 把模板单元 `gnome-blank-guard@.service` 装到 `/etc/systemd/system/`
3. 若不存在则写入示例配置 `~/.config/gnome-blank-guard.conf`
4. `systemctl enable --now gnome-blank-guard@<user>.service`

查看状态：

```bash
systemctl status gnome-blank-guard@$USER.service
journalctl -u gnome-blank-guard@$USER.service -f
```

> 单元里通过 `SupplementaryGroups=input` 让守护进程能读 `/dev/input/event*`（这些节点是 `root:input 0660`），
> 这样就不必把你自己的用户永久加入 `input` 组（该组等价于键盘记录权限）。

## 使用与验证

1. 按 `Super+L` 锁屏，等屏幕自动熄灭（或手动熄屏）。
2. 晃动鼠标、滑动触摸板 —— 屏幕应保持全黑。
3. 按一下机身**电源键** —— 屏幕点亮，锁屏界面出现，键鼠恢复正常。

日志里正常应该是这样：

```
Screen blanked; engaging guard.
Grabbed /dev/input/event3 (AT Translated Set 2 keyboard) [power=False]
...
Grabbed /dev/input/event0 (Power Button) [power=True]
Guard engaged: 11 device(s) grabbed; only the power key can wake the screen.
Notifications suppressed (show-banners=false) to prevent wake.
```

按下电源键后：

```
Power button pressed; waking the display.
Disengaging guard and releasing input devices.
Notifications restored (show-banners=true).
Set PowerSaveMode to 0.
```

## 配置

`~/.config/gnome-blank-guard.conf`（优先级更高）或 `/etc/gnome-blank-guard.conf`：

```ini
[guard]
BLOCK_MOUSE = true            # 熄屏时吞掉鼠标事件
BLOCK_TOUCHPAD = true         # 熄屏时吞掉触摸板事件
BLOCK_KEYBOARD = true         # 熄屏时吞掉键盘事件（true = 只有电源键能唤醒）
SUPPRESS_NOTIFICATIONS = true # 熄屏时临时开启勿扰，阻止通知唤醒屏幕
REENFORCE_BLANK = true        # 被意外点亮时自动重新熄灭
```

改完重启服务：

```bash
sudo systemctl restart gnome-blank-guard@$USER.service
```

## 卸载

```bash
sudo ./uninstall.sh youruser
```

## 已知限制

- 只处理 **GNOME / Mutter Wayland**。KDE、Sway、X11 等不适用。
- 熄屏期间通知不弹横幅（仍会进入通知列表，解锁后可见）。若你希望保留锁屏通知，把
  `SUPPRESS_NOTIFICATIONS` 设为 `false`，但这样消息到达时屏幕仍会被点亮。
- 电源键在熄屏时被本守护进程独占，因此熄屏状态下**无法**用电源键执行关机/挂起，
  它只负责「点亮屏幕」。需要关机请先唤醒再操作。
- 守护进程崩溃时输入设备会自动释放（进程退出即解除 `EVIOCGRAB`），不会把键鼠锁死。
- 不处理真正的 suspend；那条路径请用 `udev` 规则关闭设备的 `power/wakeup`。

## 许可证

[MIT](LICENSE)

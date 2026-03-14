# --- Монитор ---
monitor=LVDS-1,1366x768@60,0x0,1

# --- Автозапуск ---
exec-once = waybar
exec-once = swww init
exec-once = mako

# --- Ввод ---
input {
    kb_layout = ru,us
    kb_options = grp:alt_shift_toggle
    follow_mouse = 1
    touchpad { natural_scroll = yes }
}

# --- Внешний вид (Оптимизировано для G50-30) ---
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(33ccffee) rgba(00ff99ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 8
    blur { enabled = false } # Отключено для скорости
    shadow {
        enabled = true
        range = 4
        render_power = 3
        color = rgba(1a1a1aee)
    }
}

animations {
    enabled = yes
    bezier = fast, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 3, fast
    animation = fade, 1, 3, default
    animation = workspaces, 1, 2, default
}

misc {
    vfr = true 
    disable_hyprland_logo = true
}

# --- Горячие клавиши ---
$mainMod = SUPER

bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive, 
bind = $mainMod, M, exit, 
bind = $mainMod, V, togglefloating, 
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, F, fullscreen, 1

# Звук и Яркость (F-клавиши)
binde = , XF86AudioRaiseVolume, exec, pamixer -i 5
binde = , XF86AudioLowerVolume, exec, pamixer -d 5
bind  = , XF86AudioMute, exec, pamixer -t
binde = , XF86MonBrightnessUp, exec, brightnessctl set +5%
binde = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Навигация
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3

-- Cursor hardware scaling configuration (essential for NVIDIA)
hl.config({
    cursor = {
        no_hardware_cursors = true
    },
    opengl = {
        nvidia_anti_flicker = true
    },
    debug = {
        overlay = false,
        damage_tracking = 2,
        disable_logs = false
    }
})

#!/usr/bin/env python3
import sys
import os
import subprocess
import math

def send_notification(title, message, icon="video-x-generic", urgency="normal"):
    subprocess.Popen(["notify-send", title, message, "-a", "Video Editor", "-i", icon, "-u", urgency])

def main():
    if len(sys.argv) < 12:
        print("Usage: compress_video.py <input> <crop_w_ui> <crop_h_ui> <crop_x_ui> <crop_y_ui> <start_ms> <end_ms> <ui_w> <ui_h> <replace> <compress_percent>")
        sys.exit(1)

    input_file = sys.argv[1]
    crop_w_ui = float(sys.argv[2])
    crop_h_ui = float(sys.argv[3])
    crop_x_ui = float(sys.argv[4])
    crop_y_ui = float(sys.argv[5])
    start_ms = float(sys.argv[6])
    end_ms = float(sys.argv[7])
    ui_w = float(sys.argv[8])
    ui_h = float(sys.argv[9])
    replace = sys.argv[10] == "1"
    compress_percent = float(sys.argv[11])

    log_path = "/tmp/video_edit.log"
    with open(log_path, "w") as log_file:
        log_file.write(f"Processing {input_file}\n")
        log_file.write(f"UI: {ui_w}x{ui_h}, Crop: {crop_w_ui}x{crop_h_ui} at {crop_x_ui},{crop_y_ui}\n")
        log_file.write(f"Time: {start_ms}ms to {end_ms}ms\n")
        log_file.write(f"Replace: {replace}, Compress Percent: {compress_percent}%\n")

        # Get original dimensions
        try:
            dim_output = subprocess.check_output(
                ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height", "-of", "csv=s=x:p=0", input_file],
                text=True
            ).strip()
            orig_w, orig_h = map(int, dim_output.split('x'))
            log_file.write(f"Original: {orig_w}x{orig_h}\n")
        except Exception as e:
            log_file.write(f"Error getting dimensions: {e}\n")
            send_notification("Video Edit Failed", f"Could not read video dimensions. Check {log_path}", urgency="critical")
            sys.exit(1)

        start_s = start_ms / 1000.0
        end_s = end_ms / 1000.0

        filters = []
        # Only apply crop if it's not the full UI area (with some tolerance)
        w_ratio = crop_w_ui / ui_w
        if crop_w_ui != -1 and w_ratio < 0.99:
            w = int((crop_w_ui * orig_w) / ui_w)
            h = int((crop_h_ui * orig_h) / ui_h)
            x = int((crop_x_ui * orig_w) / ui_w)
            y = int((crop_y_ui * orig_h) / ui_h)

            # Ensure values are even
            w = (w // 2) * 2
            h = (h // 2) * 2
            x = (x // 2) * 2
            y = (y // 2) * 2

            filters.append(f"crop={w}:{h}:{x}:{y}")

        filter_str = ",".join(filters)
        
        # Calculate CRF based on compress percent (10 to 100)
        # 100% -> CRF 18
        # 10% -> CRF 49
        crf = int(18 + (100 - compress_percent) * 0.35)
        log_file.write(f"Calculated CRF: {crf}\n")

        dir_name = os.path.dirname(input_file)
        base_name = os.path.basename(input_file)
        name, ext = os.path.splitext(base_name)
        if not ext:
            ext = ".mp4"

        if replace:
            output_file = f"{input_file}.edited{ext}"
        else:
            i = 1
            while os.path.exists(os.path.join(dir_name, f"{name}_edited_{i}{ext}")):
                i += 1
            output_file = os.path.join(dir_name, f"{name}_edited_{i}{ext}")

        send_notification("Editing Video...", "Applying crop, cut and compression...")

        ffmpeg_cmd = [
            "ffmpeg", "-i", input_file,
            "-ss", f"{start_s:.3f}",
            "-to", f"{end_s:.3f}"
        ]

        if filter_str:
            ffmpeg_cmd.extend(["-vf", filter_str])

        ffmpeg_cmd.extend([
            "-preset", "fast",
            "-crf", str(crf),
            "-y", output_file
        ])

        log_file.write(f"Executing: {' '.join(ffmpeg_cmd)}\n")

        result = subprocess.run(ffmpeg_cmd, stdout=log_file, stderr=subprocess.STDOUT)

        if result.returncode == 0 and os.path.exists(output_file):
            if replace:
                os.replace(output_file, input_file)
                send_notification("Video Edited", f"Saved to {input_file}")
            else:
                send_notification("Video Saved", f"New copy at {output_file}")
        else:
            send_notification("Video Edit Failed", f"Check {log_path}", urgency="critical")

if __name__ == "__main__":
    main()

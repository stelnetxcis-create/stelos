#!/usr/bin/env python3
"""Download a Wallpaper Engine wallpaper to ~/Pictures/Wallpapers/.

Usage:
    download_wpe_wallpaper.py <workshop_id> [--dest <path>]

For video wallpapers: copies the .mp4/.webm file directly.
For scene wallpapers: copies the preview gif/jpg (scene.pkg is proprietary).
For web wallpapers: copies embedded .webm assets.
For preset wallpapers: resolves dependency and downloads the base wallpaper.
"""
import os
import sys
import json
import shutil
import subprocess
import argparse

def find_workshop_paths():
    roots = [
        "/mnt/01DA34356F1F3C40/SteamLibrary/steamapps/workshop/content/431960",
        os.path.expanduser("~/.local/share/Steam/steamapps/workshop/content/431960"),
        os.path.expanduser("~/.steam/steam/steamapps/workshop/content/431960"),
        os.path.expanduser("~/.steam/root/steamapps/workshop/content/431960"),
    ]
    config_path = os.path.expanduser("~/.config/illogical-impulse/config.json")
    if os.path.exists(config_path):
        try:
            with open(config_path, "r") as f:
                cfg = json.load(f)
                assets_path = cfg.get("background", {}).get("wallpaperEngineAssetsPath", "")
                if assets_path:
                    workshop_path = assets_path.replace("common/wallpaper_engine/assets", "workshop/content/431960")
                    workshop_path = workshop_path.replace("common/wallpaper_engine", "workshop/content/431960")
                    if os.path.exists(workshop_path) and workshop_path not in roots:
                        roots.insert(0, workshop_path)
        except Exception:
            pass
    return [r for r in roots if os.path.exists(r)]

def find_wallpaper_dir(wp_id):
    for root in find_workshop_paths():
        candidate = os.path.join(root, wp_id)
        if os.path.isdir(candidate) and os.path.exists(os.path.join(candidate, "project.json")):
            return candidate
    return None

def notify(summary, body="", urgency="normal"):
    try:
        cmd = ["notify-send", "-a", "WPE Download", "-u", urgency, summary]
        if body:
            cmd.append(body)
        subprocess.run(cmd, timeout=5)
    except Exception:
        pass

def sanitize_filename(name):
    """Remove or replace characters that are problematic in filenames."""
    for ch in ['/', '\\', ':', '*', '?', '"', '<', '>', '|']:
        name = name.replace(ch, '_')
    return name.strip()

def download_wallpaper(wp_id, dest_dir):
    wp_dir = find_wallpaper_dir(wp_id)
    if not wp_dir:
        notify("Download failed", f"Wallpaper {wp_id} not found on disk.", "critical")
        return False

    project_json_path = os.path.join(wp_dir, "project.json")
    with open(project_json_path, "r") as f:
        data = json.load(f)

    title = data.get("title", f"Wallpaper_{wp_id}")
    wp_type = data.get("type", "NONE")
    file_ref = data.get("file", "")
    preview = data.get("preview", "")
    dependency = data.get("dependency", "")

    safe_title = sanitize_filename(title)
    os.makedirs(dest_dir, exist_ok=True)

    # If this is a preset/dependency, resolve the base wallpaper
    if wp_type == "NONE" and dependency:
        notify("Resolving dependency...", f"Preset '{title}' depends on {dependency}")
        return download_wallpaper(dependency, dest_dir)

    downloaded_files = []

    # For video wallpapers: copy the actual video file
    if wp_type.lower() == "video" and file_ref:
        src = os.path.join(wp_dir, file_ref)
        if os.path.exists(src):
            ext = os.path.splitext(file_ref)[1]
            dest = os.path.join(dest_dir, f"{safe_title}{ext}")
            # Avoid overwriting if same file exists
            if os.path.exists(dest) and os.path.getsize(dest) == os.path.getsize(src):
                notify("Already downloaded", f"'{title}' is already in your wallpapers folder.")
                return True
            shutil.copy2(src, dest)
            downloaded_files.append(dest)
            notify("Downloaded!", f"Video saved: {safe_title}{ext}")
            return True
        else:
            notify("Download failed", f"Video file not found: {file_ref}", "critical")
            return False

    # For web wallpapers: copy embedded .webm/.mp4 assets
    if wp_type.lower() == "web":
        video_exts = ('.mp4', '.webm', '.avi', '.mov')
        for fname in os.listdir(wp_dir):
            if fname.lower().endswith(video_exts):
                src = os.path.join(wp_dir, fname)
                dest = os.path.join(dest_dir, f"{safe_title}_{fname}")
                if not os.path.exists(dest) or os.path.getsize(dest) != os.path.getsize(src):
                    shutil.copy2(src, dest)
                downloaded_files.append(dest)
        if downloaded_files:
            notify("Downloaded!", f"Web wallpaper assets saved: {safe_title} ({len(downloaded_files)} files)")
            return True

    # For scene wallpapers (and fallback): save the preview
    if preview:
        preview_path = os.path.join(wp_dir, preview)
        if os.path.exists(preview_path):
            ext = os.path.splitext(preview)[1]
            dest = os.path.join(dest_dir, f"{safe_title}{ext}")
            if not os.path.exists(dest) or os.path.getsize(dest) == os.path.getsize(preview_path):
                if os.path.exists(dest):
                    notify("Already downloaded", f"'{title}' preview is already saved.")
                    return True
            shutil.copy2(preview_path, dest)
            downloaded_files.append(dest)

            # If it's a gif, also try to extract a static frame as .png
            if ext.lower() == '.gif':
                try:
                    png_dest = os.path.join(dest_dir, f"{safe_title}.png")
                    subprocess.run(
                        ["ffmpeg", "-y", "-i", preview_path, "-vframes", "1", png_dest],
                        capture_output=True, timeout=10
                    )
                    if os.path.exists(png_dest):
                        downloaded_files.append(png_dest)
                except Exception:
                    pass

            notify("Downloaded!", f"Preview saved: {safe_title}{ext}\n(Scene wallpapers can only export previews)")
            return True

    # If we got here, nothing was downloadable
    notify("Download failed", f"No downloadable content found for '{title}' (type: {wp_type})", "critical")
    return False

def main():
    parser = argparse.ArgumentParser(description="Download a WPE wallpaper to ~/Pictures/Wallpapers/")
    parser.add_argument("workshop_id", help="Steam Workshop ID of the wallpaper")
    parser.add_argument("--dest", default=os.path.expanduser("~/Pictures/Wallpapers"),
                        help="Destination directory (default: ~/Pictures/Wallpapers)")
    args = parser.parse_args()

    success = download_wallpaper(args.workshop_id, args.dest)
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()

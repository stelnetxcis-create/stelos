# [ StelOS ]

Premium Material 3 / Material You dotfiles for Hyprland, powered by Quickshell.

## System Preview

<img width="1924" height="1095" alt="StelOS desktop preview" src="REPLACE_WITH_YOUR_SCREENSHOT_URL" />


## Overview

**StelOS** is a personal, agentic desktop OS by Cyna, with its Quickshell configuration layer (**StelNetQS**) built on top of **[illogical-impulse](https://github.com/end-4/dots-hyprland)**. **This is a personal customization. It's not focused on performance or stability — if you use it, expect a lot of bugs.** If you find one, please open an issue on this repository.

It aims to provide a state-of-the-art Linux desktop experience by strictly adhering to **Material 3 (Material You)** design principles, featuring dynamic theming via Matugen and a highly modular architecture built on **Quickshell**.

> [!NOTE]
> This repository is a work in progress. Some modules, like the Gmail client, require manual setup of API keys.

## Requirements

- **Hyprland 0.56.1 or newer**
- **Matugen 4.1.0 or newer**
- **quickshell-git 0.3.0 or newer**

> [!NOTE]
> Matugen **4.1.0+ is the supported/recommended version**. The lightweight scheme-switching path still detects Matugen 3 and avoids the Matugen 4-only `--source-color-index` option, preserving scheme changes on older installations. On Fedora, the installer enables `avengemedia/danklinux` to source the current Matugen package.

## Installation

### Default installation

Use this if you don't have illogical-impulse already installed. It sets up the base
dotfiles and everything they need, then puts the StelNetQS config on top.

```bash
git clone --recurse-submodules https://github.com/stelnetxcis-create/stelos.git
cd stelos
./setup-ii-stelnet.sh install
```

### Minimal installation (only quickshell config)

Use this if illogical-impulse is already working and you only want the StelNetQS Quickshell config.
Nothing else is touched, and your current config is moved to a backup rather than deleted.

```bash
git clone --recurse-submodules https://github.com/stelnetxcis-create/stelos.git
cd stelos
./setup-ii-stelnet.sh
```

## Documentation

Please refer to the **[illogical-impulse wiki](https://end-4.github.io/dots-hyprland-wiki/en/ii-qs/02usage/)** for detailed component descriptions.

<details> <summary><strong>🛠 Common Issues</strong></summary>

<br>

### Dynamic colors / Matugen are not working

If wallpaper colors are not being applied and you see an error such as:

> matugen exited with an error, so the shell kept its previous palette.

First, make sure you are running:

- **Matugen** 4.1.0 or newer
- **quickshell-git** 0.3.0 or newer

You can check the installed versions with:

```bash
matugen --version
quickshell --version
```

#### Arch Linux / CachyOS

Make sure you are using the AUR `quickshell-git` package, rather than another Quickshell build provided by a third-party repository.

A reported case on CachyOS was caused by the system using the Noctalia Quickshell package from the CachyOS repositories instead of `aur/quickshell-git`. Replacing it with the AUR package fixed Matugen and dynamic colors.

```bash
yay -S aur/quickshell-git
```

If another Quickshell package is installed, your package manager may ask to replace the conflicting package.

---

### Quickshell stopped working after a Qt update

Quickshell may stop starting correctly after a Qt update if the installed `quickshell-git` package was compiled against the previous Qt version.

For example, this can happen after updates such as:

```
Qt 6.11.1 -> Qt 6.11.2
```

Rebuild `quickshell-git` against the newly installed Qt libraries:

```bash
yay -S --rebuild aur/quickshell-git
```

Then restart Quickshell.

If rebuilding does not solve the problem, completely reinstall `quickshell-git` using your AUR helper.

> **💡 Tip**
>
> If the shell suddenly stops working immediately after a Qt system update, rebuilding `quickshell-git` should be one of the first troubleshooting steps.

</details>

## Credits

- **[end-4](https://github.com/end-4):** Creator of illogical-impulse.
- **Cyna:** Creator of StelOS.
- **Xenna:** Agentic assistant behind StelOS.
- **[Quickshell](https://quickshell.org/):** Widget system.
- **[Hyprland](https://hypr.land/):** Compositor.

---

<div align="center">
    <p><b>If you like this project, consider giving it a star! ⭐</b></p>
</div>

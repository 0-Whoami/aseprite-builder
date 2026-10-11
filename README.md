# Aseprite Builder 🎨

This project provides an easy, automated way to get your own copy of **Aseprite** by building it directly from the official source code. 

Aseprite is "source-available" software. This means while the pre-made versions are paid, the creators allow you to compile the code yourself for personal use. This repository does all the hard work for you-automatically setting up the environment and creating a ready-to-use installer.

---

## ✨ Features
* **Free & Legal:** Automatically builds your own personal copy from the official code.
* **No Software Needed:** Everything can happen in the "cloud" on GitHub.
* **Fixes Common Errors:** Automatically includes the necessary files (Skia and OpenSSL) so the app works immediately after installation.
* **Simple Installer:** Creates a standard Windows `.exe` setup file for you to download.

---

## 🚀 How to Get Aseprite

### Method 1: Cloud Build (Recommended)
You can build Aseprite directly on GitHub's servers without installing anything on your computer.

1. **Fork** this repository to your account.
2. Go to the **Actions** tab in your new repository.
3. Click **"Build Aseprite"** on the left.
4. Click the **Run workflow** button.
5. **Wait about 25 minutes.** When the green checkmark appears, go to the **Releases** section on the right side of your project's home page to download your `aseprite-setup.exe`.

### Method 2: Local Build
If you prefer to compile the software on your own machine, you can use the provided batch script.

1. Ensure you have **Visual Studio 2022**, **CMake**, and **Ninja** installed.
2. Download the `build_aseprite.bat` file from this repository.
3. Right-click the script and select **"Run as Administrator"**.
4. The script will automatically download the source and build the installer in a local folder.

---

## ⚖️ A Quick Legal Note
* **Personal Use Only:** You are allowed to build this for yourself, but you are **not** allowed to sell it or share the `.exe` file publicly.
* **Support the Creators:** If you enjoy the software, please consider [buying it officially](https://www.aseprite.org/) to support the original developers.

---

## 🛠 Troubleshooting
* **Windows Warning:** Because you built this yourself, Windows might say it doesn't recognize the "publisher." Click **"More Info"** and then **"Run anyway."**
* **Build Failed?** If the build stops with a red "X," just try running it again. Sometimes the cloud servers have temporary hiccups.

---

## 📝 Recent Improvements

### Fixed Issues
1. **Removed interactive prompts** - The batch script no longer asks for confirmation, making it CI/CD compatible
2. **Better dependency handling** - CMake, Ninja, and Inno Setup are now installed via Chocolatey with proper error handling
3. **Robust download logic** - Uses PowerShell's `Expand-Archive` instead of relying on `7z` (which may not be available in all environments)
4. **Improved Visual Studio detection** - Uses `vswhere.exe` with fallback to common install paths
5. **Better error handling** - Each step has proper error checking with meaningful error messages
6. **Dynamic parallel compilation** - Automatically detects CPU cores and uses optimal job count for Ninja builds
7. **OpenSSL DLL handling** - Checks for OpenSSL DLLs before copying, preventing failures if they're missing

### How to Use
- **GitHub Actions:** Fork the repo, go to **Actions** → **Build Aseprite** → **Run workflow**
- **Local Build:** Run `aseprite_build.bat` as Administrator

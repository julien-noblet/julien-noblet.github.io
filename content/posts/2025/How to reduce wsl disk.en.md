---
categories:
- tips
date: "2025-04-02T23:00:00+02:00"
tags:
- wsl
Language: en
title: How to reduce wsl disk
description: A guide to compacting and reducing the size of your WSL disk to save space.
---
As you use WSL, the VHDX disk image will grow. You need to compact it!

## 1. Cleanup

Start by cleaning up the disk. Each user can choose their preferred method.

## 2. fstrim

Once everything is clean, you can force the system to discard unused elements from the image.
```shell
sudo fstrim -av
```

## 3. Installing wslcompact

The [wslcompact](https://github.com/okibcn/wslcompact) project is a PowerShell module that allows you to compact the disk efficiently.

```posh
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb https://raw.githubusercontent.com/okibcn/wslcompact/main/setup | iex
```

*Note: On the latest versions of WSL (2.5.4.0?), you may need to patch the file as shown in [this commit](https://github.com/gotenksIN/wslcompact/commit/8a39e5375b202848a03f122311f94fa7c01add86).*

## 4. Running the script

This will shut down WSL, copy the disk data into a new VHDX, and then replace the old one.

```posh
WslCompact -c -d
```

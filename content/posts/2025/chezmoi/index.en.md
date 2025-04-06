---
title: Chezmoi, how I manage my dotfiles
date: "2025-04-06T16:00:00+02:00"
tags:
- chezmoi
- dotfiles
- configuration
- Linux
ShowToc: true
---
Some time ago, I had to reinstall my Linux work environment.

As usual, I started by configuring my tools:
- git
- neovim
- rclone
- restoring my SSH keys
- reconfiguring my .bashrc 
- ...

After a few ~~hours~~ days, my environment was usable the way I like it.

A few weeks passed, and I moved from one Raspberry Pi to another, from one machine to another, grumbling because my environment wasn’t necessarily present on those machines (rightly or wrongly).

Then my machine broke down. I replaced it and had to configure my environment all over again.

I changed disks, same story... An SD card burned out in a Raspberry Pi... Start over...

I adopted a new tool and regretted not finding it on my other machines...

Until the day I decided to no longer let fate dictate my productivity!

## I discovered Chezmoi ##
[Chezmoi](https://www.chezmoi.io/) is a tool that simplifies the maintenance and deployment of your environments, whether at home, at work, on your dev machine, or during an admin session...

OK, but what does it look like?

Chezmoi is a DOTFILES manager, you know, the files that start with a `.` in your `$HOME`.

In fact, Chezmoi allows you to store your configuration files in a git repository.

Sure, pushing files to a git repo doesn’t require a tool...

Think again! 
The magic lies in its ability to script, template, and encrypt these dotfiles.

It also notifies you when your environment is out of sync with the remote repo and offers to update your environment.

## Installation ##

We’ll install it using [ASDF](/posts/2025/asdf) 

```bash
asdf plugin install chezmoi && asdf install chezmoi latest && asdf set -u chezmoi latest
```
We’ll also install [AGE](https://age-encryption.org/), which will help us encrypt our secrets.
```bash
asdf plugin install age && asdf install age latest && asdf set -u age latest
```

Next, we’ll prepare the git repo we’ll use to publish/save our files.
If you have a GitHub account, I recommend creating a "dotfiles" repository.

Now, initialize:
```bash
chezmoi init --ssh <my_github_user> --apply
```
(If you don’t have a GitHub account or want to store your dotfiles elsewhere, [check the documentation](https://www.chezmoi.io/reference/commands/init/))


Now:
```bash
chezmoi add ~/.bashrc
```

Make a modification to the file, then run `chezmoi apply`, and the file will revert to its original state!

Go to Chezmoi’s working directory with `chezmoi cd`, and you’ll find your bashrc file named `dot_bashrc`.

Chezmoi uses a naming convention to add attributes to your files. If you’re interested, [check the documentation](https://www.chezmoi.io/reference/target-types/)

You can also template and script everything!

(We’ll come back to this later)

# If you want examples: 
 - [felipecrs/dotfiles](https://github.com/felipecrs/dotfiles) (which I drew a lot of inspiration from)
 - [renemarc/dotfiles](https://github.com/renemarc/dotfiles) (same here)
 - [My dotfiles](https://github.com/julien-noblet/dotfiles)
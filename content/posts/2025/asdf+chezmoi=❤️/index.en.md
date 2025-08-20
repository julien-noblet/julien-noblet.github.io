---
title: asdf + chezmoi = ❤️
date: "2025-08-20T08:00:00+02:00"
tags:
- asdf
- Linux
- tools
- devops
- chezmoi
- dotfiles
- configuration
ShowToc: false
categories:
- tips
- tools
description: "An overview of using chezmoi to manage your tool versions with asdf"
---

In a previous post, I mentioned we would revisit [chezmoi](/posts/2025/chezmoi) templates. Today, let's explore how to use these templates to manage your tool versions with [asdf](/posts/2025/asdf).

## Data

Chezmoi lets you define a mini database to store whatever you want!
These data must be defined in the [.chezmoidata/](https://www.chezmoi.io/reference/special-directories/chezmoidata/) folder.

Let's start by creating an `asdf.yaml` file in this folder to store our tool versions.

{{% include displayName="`.chezmoidata/asdf.yaml` :" src=asdf.yaml lang=yaml %}}

## Templates

Chezmoi allows you to use templates to customize your configuration files. You can use variables to replace values in your files.

Chezmoi templates use the Go template language. More precisely, they use Go's [text/template](https://pkg.go.dev/text/template) library for rendering. This means you can use all the features of this library, including functions, pipelines, and conditions. [See the documentation](https://www.chezmoi.io/reference/templates/)

Here, we'll generate the `~/.tool-versions` file from the data defined in `asdf.yaml`.

Quick reminder: the file starts with a dot 👉 so we need to use `dot` to symbolize it. Add `.tmpl` to indicate it's a template.

{{% include displayName="`~/dot_tool-versions.tmpl` :" src=dot_tool-versions.tmpl lang=yaml %}}

Simple, right?

### Template explanation

- `{{ range .asdf.tools -}}` creates a loop to iterate over each tool defined in `asdf.yaml`.
- `{{ .name }} {{ .version }}` displays the name and version of each tool.
- `{{ end }}` ends the loop.

## Scripts

Where chezmoi excels is in script management. You can easily define scripts to run when certain files are modified.

In our case, chezmoi will update our `.tool-versions`, but it can also run the necessary commands for asdf to install the tools!

Even better, you can combine templates and scripts to further automate your workflow.

Let's create the file `run_onchange_dot_tool-version.sh.tmpl` in the `.chezmoiscripts/` folder.

{{% include displayName="`.chezmoiscripts/run_onchange_dot_tool-version.sh.tmpl` :" src=run_onchange_dot_tool-version.sh.tmpl lang=bash %}}

### Script explanation

I'll just cover the main points:

- The script starts by checking if the operating system is Linux.
- It defines a function to install asdf.
- It ensures the folder needed for asdf installation exists.
- It checks if asdf is already installed, and if not, installs it.
- For each tool, it checks that the plugin is installed and up to date.
- For each tool, it ensures the version specified in `~/.tool-versions` is installed.
- Finally, for each tool, it cleans up old versions.

# Conclusion

We've seen how to use chezmoi to manage tool versions with asdf. By combining templates and scripts, you can automate your workflow and ensure your tools are always up to date. Feel free to explore more chezmoi features and adapt them to your needs.

Note: data files cannot be templated (at least for now).

Once again, you can get inspiration from [my dotfiles](https://github.com/julien-noblet/dotfiles).

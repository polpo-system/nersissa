# nersissa

The package manager of the [polpo](https://github.com/polpo-system/polpo) desktop: a panel of gadgets
over portia. The categories of the package tree are at the left, the packages of the chosen category
at the upper right, and the description of the chosen package below them. A button installs the
package, or removes it when it is installed; another upgrades it when the tree has a newer version.

Nersissa is Portia's waiting-gentlewoman in The Merchant of Venice.

```
portia.Install nersissa
```

It comes with gadgets-desktop.

## Using

    Nersissa.Open      the panel in a viewer of the desktop; run from a shell, without the
                       desktop (loksh Nersissa.Open), in a window of its own

A middle click on a category lists its packages, a middle click on a package describes it: its
version, whether it is installed, what it depends on, its modules. In the lists, `[x]` marks an
installed package, `[ ]` one that is not installed and `[u]` one that is installed with a newer
version in the tree. Besides portia's categories there are three of its own: all, installed and
upgradable.

The buttons:

    Install, Remove    portia.Install /y or portia.Remove /y with the package described; the caption
                       says which one, after the state of the package
    Upgrade            portia.Install /y: the newer version of the tree
    Sync               portia.Sync: the newest package tree from GitHub

portia does the work and writes its messages into System.Log; the panel then shows the new state.
portia refuses to remove a package that installed packages need. The panel is as wide as the left
track of the screen (at most 1000 pixels) and as high as the screen allows.

## What is here

    src/Nersissa.Mod       the panel and its commands, on portia.Reload, portia.GetPackage and
                           portia.Describe
    tools/Nersissa.Tool
    test/NersissaTest.Mod

## Tests

    NersissaTest.Run   13 checks: the panel made from the tree, its lists, a category chosen, a
                       package described with its state and the caption of the button; nothing is
                       installed or removed; it needs the desktop's display

The license is GPL-3 (`LICENSE`).

# CCLinker

Swipe a Control Center module to jump straight to its settings.

| Module | Opens |
|---|---|
| Wi-Fi, Bluetooth, Cellular Data, Personal Hotspot, AirDrop, VPN | Their page in Settings |
| Focus, Low Power Mode | Their page in Settings |
| Music widget | The now playing app (falls back to Music), or a chosen app |

Settings → CCLinker lets you pick the gesture (swipe right, left, up or down, or hold), toggle haptics,
turn individual links on or off, and choose the music app from a searchable list. Changes apply
without a respring.

Links also work in the expanded connectivity module, which is where AirDrop and Personal Hotspot
live. Other modules ignore the gesture while expanded.

With Hold, holding a linked module opens its link instead of expanding it. Holding a module
without a link, or the space between the connectivity buttons, still expands it.

Available from [tibi1220's Repo](https://tibi1220.github.io/repo/) for rootful, rootless and roothide.

## How it works

- Hooks `CCUIContentModuleContainerViewController -viewDidLoad` in SpringBoard to add a swipe and a
  hold recognizer to every module, enabling whichever gesture is selected.
- Identifies the module by its `moduleIdentifier`. Inside the connectivity module, it walks up
  the responder chain from the touched view to find the button's view controller
  (`CCUIConnectivityWifiViewController`, …).
- Dismisses Control Center and opens the target through `FBSSystemService`, unlocking the
  device first when needed.
- Modules without a link are logged as `[CCLinker] No link for module <identifier>`, so you can
  find identifiers to add.

## Building

Requires [Theos](https://theos.dev) with the iOS 16.5 SDK. Roothide builds need the
[roothide Theos fork](https://github.com/roothide/theos).

```sh
make package                                # rootful
make package THEOS_PACKAGE_SCHEME=rootless
make package THEOS_PACKAGE_SCHEME=roothide
make do THEOS_DEVICE_IP=<device ip>         # build, install and respring
```

On macOS, use `gmake`: Theos needs GNU Make 4+.

## Releasing

1. Bump `Version` in `control`, and add the changelog to `depiction/depiction.json`.
2. Tag and push: `git tag v1.0.1 && git push --tags`.

The build workflow compiles all three schemes on every push and pull request. For a tag, it also
attaches the debs to a GitHub release, and triggers a rebuild of the repo if the
`REPO_DISPATCH_TOKEN` secret is set.

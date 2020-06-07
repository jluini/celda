# Celda

**Celda** is a game developed as a first prototype within the incipient *Grog* framework. Both the game and the
framework are still incomplete and not fully usable, but they're working.


# About Grog

**Grog** is a Godot's framefork for point &amp; click adventure games. Its name stands for "Godot's recipe of grog";
note that this acronym is **not** recursive as the *grog* word it contains refers to a well-known fantasy drink and
not to the framework itself.

It works in Godot 3.2. Its documentation is [here](docs/index.md) (still incomplete).

# Project structure

The entry point ([standard_runner](src/apps/standard_runner/)) is an instance of the 
[modular](src/tools/modular/) tool, which allows to load a set of components and send messages between
them in a decoupled fashion. Some of those components (usually one) are the *apps* which run as fullscreen and are meant
to be the actual interface to the users. The rest are *modules* which run behind-the-scenes and are shown as tabs in a secret
interface for debugging purposes; there's a special first tab showing the log messages which are organized by the modular tool
aswell (this allows having logs even in devices without a console like phones).

In this case the app is a *grog-client* ([modern_client](src/clients/modern_client/), the only one available at the moment)
and relies in the *grog-server* module. In addition to this there's a *theme-switcher* module for changing themes on-the-fly
(currently affects only fonts) and another (*fede-loopin*) responsible for playing music songs with customizable transitions
between them.


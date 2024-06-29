# NES GAME - UFO MOVEMENT

A basic nes "game" that moves a colored UFO sprite on a black background. Used to understand the basics of the NES architecture and 6502 assembly. 



### Compiling and Executing on Emulator

```
:: Put in a .bat file

:: Change Directory
cd "project directory"

:: For debug and object files
ca65 spacetry2.s -o spacetry2.o --debug-info
ld65 spacetry2.o -o spacetry2.nes -t nes --dbgfile spacetry2.dbg

:: Running on an emulator (.nes)
:: With Mesen --> spacetry2.nes
:: With FCEUX --> "fceux.exe" "projectDirectory\spacetry2.nes"
spacetry2.nes
```
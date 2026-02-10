# MyKernel0.03

## New features that will be in this version: 
Curently now: After kernel loads, it will ask user to restart and boot the ***epik*** assembly image (tomo.png), or any other image, so that it gets displayed on screen
Currently now: makfile automatically calls python program to convert the image, no need to run it yourself, make sure tomo.png is in the project folder and then you run make clean && make all

Not currently implemented: [will go here in the future]

### Instructions
Currently not working correctly

Make sure to install i686 elf tools and put it as path (once installed run this command in msys2 mingw64): export PATH="/c/i686-elf-tools/bin:$PATH"
No need to convert os image bin file to img and pad to floppy size, makefile does this automatically

Works with qemu so make sure it's installed in msys2 (ex run "qemu-system-i386 -fda os-image.img -boot a -vga cirrus" to boot off of it (can use std instead of cirrus))

If python code doesn't execute correctly due to pip and/or PIL not being installed in msys2 mingw64, make sure you have pip installed, run "python -c "import sys; print(sys.executable)" 
it will give you a directory, run "<that_full_path> -m pip install --upgrade pillow", of course you need to replace the placeholder with the actual path 

then install pillow with "pacman -S mingw-w64-x86_64-python-pillow" and answer yes to the prompts.
once this is done try to build the project again

If it still doesn't work, try running these:

- pacman -Syu
- pacman -S mingw-w64-x86_64-python
- pacman -S mingw-w64-x86_64-python-pillow

After that, test with:
python -c "from PIL import Image; print('Success')"

If it prints it then all is good and you can make clean && make all

import std.stdio;
import emucpu;
import insset;
import nesrom;
import emuppu;
import core.thread.osthread;
import core.time;
import std.datetime.stopwatch;
import std.concurrency;
import core.atomic;
import arsd.simpledisplay;

enum CLEAR = "\x1b[2J\x1b[H";
enum RunningMode {
	RUNNING, PAUSED, TSDEBUG
}
auto curMode = RunningMode.RUNNING;
void main(string[] argv) {
	if (argv.length != 2) {
		writefln!"Usage: %s <rom>.nes"(argv[0]);
		return;
	}
	auto rom = readRom(argv[1]);
	auto nes = EmuCPU(getDefaultIS());
	nes.mem.silenceUnmapped = false;
	auto ppu = EmuPPU(rom);
	bool[8] buttonsPressed;
	ubyte whichButton;
	ppu.ppuMem.cpu = &nes;
	initPalette();
	mapRom(rom, nes.mem);
	ubyte[0x8000] ramBuf;
	ubyte bufRead(ushort addr) {
		return ramBuf[addr & 0x07FF];
	}
	void bufWrite(ushort addr, ubyte val) {
		ramBuf[addr & 0x07FF] = val;
	}
	void ppuCtrlWrapper(ushort addr, ubyte val) {
		ppu.ppuCtrl(val, nes);
	}
	void ppuMaskWrapper(ushort addr, ubyte val) {
		ppu.ppuMask(val);
	}
	ubyte ppuCtrlReader(ushort addr) {
		return ppu.ppuCtrlRead();
	}
	ubyte ppuStatusWrapper(ushort addr) {
		return ppu.ppuStatus();
	}
	void oamAddrWrapper(ushort addr, ubyte val) {
		ppu.oamAddr(val);
	}
	void oamDataWrapper(ushort addr, ubyte val) {
		ppu.oamData(val);
	}
	ubyte oamDataReader(ushort addr) {
		return ppu.oamDataRead();
	}
	void ppuScrollWrapper(ushort addr, ubyte val) {
		ppu.ppuScroll(val);
	}
	void ppuAddrWrapper(ushort addr, ubyte val) {
		ppu.ppuAddr(val);
	}
	void ppuDataWrapper(ushort addr, ubyte val) {
		ppu.ppuData(val);
	}
	ubyte ppuDataReader(ushort addr) {
		return ppu.ppuDataRead();
	}
	ubyte arbitraryRead(ushort addr) {
		return 0x66;
	}
	void arbitraryWrite(ushort addr, ubyte val) {
		//
	}
	void oamDmaWrapper(ushort addr, ubyte val) {
		ppu.oamDma(val, nes);
	}
	ubyte controller1Read(ushort addr) {
		if (whichButton >= 8) return 1;
		return buttonsPressed[whichButton++] ? 1 : 0;
	}
	void controller1Write(ushort addr, ubyte val) {
		if (val & 1) {
			whichButton = 0;
		}
	}
	nes.mem.createMap(0x0000, 0x07FF, &bufRead, &bufWrite);
	nes.mem.createMap(0x0800, 0x0FFF, &bufRead, &bufWrite);
	nes.mem.createMap(0x1000, 0x17FF, &bufRead, &bufWrite);
	nes.mem.createMap(0x1800, 0x1FFF, &bufRead, &bufWrite);
	nes.mem.createMap(0x2000, 0x2000, &ppuCtrlReader, &ppuCtrlWrapper);
	nes.mem.createMap(0x2001, 0x2001, &arbitraryRead, &ppuMaskWrapper);
	nes.mem.createMap(0x2002, 0x2002, &ppuStatusWrapper, &arbitraryWrite);
	nes.mem.createMap(0x2003, 0x2003, &arbitraryRead, &oamAddrWrapper);
	nes.mem.createMap(0x2004, 0x2004, &oamDataReader, &oamDataWrapper);
	nes.mem.createMap(0x2005, 0x2005, &arbitraryRead, &ppuScrollWrapper);
	nes.mem.createMap(0x2006, 0x2006, &arbitraryRead, &ppuAddrWrapper);
	nes.mem.createMap(0x2007, 0x2007, &ppuDataReader, &ppuDataWrapper);
	nes.mem.createMap(0x4016, 0x4016, &controller1Read, &controller1Write); // just get it to SHUT UP
	nes.mem.createMap(0x4017, 0x4017, &arbitraryRead, &arbitraryWrite);
	nes.mem.createMap(0x4014, 0x4014, &arbitraryRead, &oamDmaWrapper);
	//nes.mem.createMap(0x4011, 0x4011, &arbitraryRead, &arbitraryWrite);
	//nes.mem.createMap(0x4000, 0x400f, &arbitraryRead, &arbitraryWrite);	
	writeln("Beginning execution!");
	uint frames = 0;
	auto fpsTimer = StopWatch(AutoStart.yes);
	ushort scanAddr;
	ushort[] monitor = [46, 2094, 4142, 6190];
	nes.mem.watchPts ~= 46;
	nes.mem.silenceWatch = true;
	nes.triggerInterrupt(IntType.RESET);
	while (nes.steps < 30000) nes.step();
	nes.steps = 0;
	ppu.screen.eventLoop(17, () {
		if (curMode == RunningMode.PAUSED) {
			ushort[] foundAddrs;
			foreach (ushort address; 0..0x2000) {
				if (nes.mem[address] == (scanAddr >> 8) && nes.mem[cast(ushort)(address+1)] == (scanAddr & 0xFF)) {
					foundAddrs ~= address;
				}
			}
			writefln("%sExecution paused", CLEAR);
			writefln("Found addresses: %s", foundAddrs);
			return;
		}
		ppu.drawFrame(nes);
		frames++;
		if (fpsTimer.peek() >= dur!"seconds"(1)) {
			writefln("%sCurrently: %s\nCurrent FPS: %d; current CPU speed: %d k", CLEAR, curMode, frames, nes.steps/1000);
			foreach (sprite; 0..1) {
                                ubyte[] oamEntry = ppu.oam[sprite << 2 .. (sprite + 1) << 2];
                                ubyte spriteX = oamEntry[3];
                                ubyte spriteY = oamEntry[0];
                                ubyte whichTile = oamEntry[1];
                                ubyte attr = oamEntry[2];
                                writefln("Sprite: %2d X: %3d Y: %3d Tile: %3d Attributes: %08b", sprite, spriteX, spriteY, whichTile, attr);
                        }
			foreach (addr; monitor) {
				writefln("Address: %04x Value: %02x (%02x)", addr, nes.mem[addr], nes.mem[cast(ushort)(addr+1)]);
			}
			writefln("s0hit: %s", ppu.sprZeroHit);
			nes.steps = 0;
			frames = 0;
			fpsTimer.reset();
		}
	}, delegate(KeyEvent ke) { 
		switch(ke.key) {
			case Key.W:
				buttonsPressed[4] = ke.pressed;
				break;
			case Key.A:
				buttonsPressed[6] = ke.pressed;
				break;
			case Key.S:
				buttonsPressed[5] = ke.pressed;
				break;
			case Key.D:
				buttonsPressed[7] = ke.pressed;
				break;
			case Key.Space:
				buttonsPressed[0] = ke.pressed;	
				break;
			case Key.Enter:
				buttonsPressed[3] = ke.pressed;
				break;
			case Key.Shift:
				buttonsPressed[2] = ke.pressed;
				break;
			case Key.Tab:
				buttonsPressed[1] = ke.pressed;
				break;
			case Key.P:
				if (ke.pressed) break;
				if (curMode == RunningMode.PAUSED) {
					curMode = RunningMode.RUNNING;
					break;
				}
				curMode = RunningMode.PAUSED;
				write("PAUSED, enter value to search for (hex): ");
				readf!"%x\n"(scanAddr);
				break;
			default: break;
		}
	});
	   /*
	while (true) {
		nes.step();
		steps++;
		if (vblanks.peek() >= dur!"msecs"(17)) {
			ppu.drawFrame(nes);
			if (vblanks.peek() >= dur!"msecs"(34)) {
				writeln("WARNING: rendering can't keep up!");
			}				
			vblanks.reset();
			frames++;
		}
		if (fpsTimer.peek() >= dur!"seconds"(1)) {
			writefln("%sCurrent FPS: %d; current CPU speed: %d k", CLEAR, frames, steps/1000);
			steps = 0;
			frames = 0;
			fpsTimer.reset();
			foreach (sprite; 0..64) {
				ubyte[] oamEntry = ppu.oam[sprite << 2 .. (sprite + 1) << 2];
				ubyte spriteX = oamEntry[3];
				ubyte spriteY = oamEntry[0];
				ubyte whichTile = oamEntry[1];
				ubyte attr = oamEntry[2];
				writefln("Sprite: %2d X: %3d Y: %3d Tile: %3d Attributes: %08b", sprite, spriteX, spriteY, whichTile, attr);
			}
		}
	}*/
}

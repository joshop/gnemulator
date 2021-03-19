import std.stdio;
import emucpu;
import insset;
import nesrom;
import emuppu;
import core.thread.osthread;
import core.time;
import std.datetime.stopwatch;

enum CLEAR = "\x1b[2J\x1b[H";
void main(string[] argv) {
	if (argv.length != 2) {
		writefln!"Usage: %s <rom>.nes"(argv[0]);
		return;
	}
	auto rom = readRom(argv[1]);
	auto nes = EmuCPU(getDefaultIS());
	auto ppu = EmuPPU(rom);
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
		return 0x00;
	}
	void arbitraryWrite(ushort addr, ubyte val) {
		//
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
	nes.mem.createMap(0x4016, 0x4016, &arbitraryRead, &arbitraryWrite);
	nes.mem.createMap(0x4017, 0x4017, &arbitraryRead, &arbitraryWrite);
	nes.triggerInterrupt(IntType.RESET);
	writeln("Beginning execution!");
	auto vblanks = StopWatch(AutoStart.yes);
	while (true) {
		nes.step();
		if (vblanks.peek() >= dur!"msecs"(30)) {
			ppu.drawFrame(nes);
			vblanks.reset();
		}
	}
}

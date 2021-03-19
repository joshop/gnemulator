module nesrom;
import std.stdio;
import std.conv;
import std.format;
import emucpu: Memory;

enum Mirror {
	HORIZ,
	VERT
}

struct NESRom {	
	bool corrupt;
	ubyte prgRomSize;
	ubyte chrRomSize;
	ubyte mapperNo;
	ubyte flags6;
	ubyte flags7;
	ubyte flags8;
	ubyte flags9;
	ubyte flags10;
	Mirror mirroring;
	bool hasPrgRam;
	bool hasTrainer;
	bool hasFourScreen;
	char[512] trainer;
	char[][] prgRom;
	char[][] chrRom;
}
class RomWriteException : Exception {
	this (string msg) {
		super(msg);
	}
}
NESRom readRom(string path) {
	auto romFile = File(path);
	auto romContents = romFile.rawRead(new char[romFile.size()]);
	auto rom = NESRom();
	writefln("Reading rom %s...", path);
	writefln("Header contains '%s'", romContents[0..4]);
	if (romContents[0..4] != "NES\x1A") {
		rom.corrupt = true;
		writeln("Invalid ROM header. Exiting.");
		return rom;
	}
	rom.prgRomSize = romContents[4];
	rom.chrRomSize = romContents[5];
	writefln("Rom has %d blocks of PRGROM and %d blocks of CHRROM.", rom.prgRomSize, rom.chrRomSize);
	rom.flags6 = romContents[6];
	rom.flags7 = romContents[7];
	rom.flags8 = romContents[8];
	rom.flags9 = romContents[9];
	rom.flags10 = romContents[10];
	rom.mapperNo = (rom.flags6 >> 4) + (rom.flags7 & 0xF0);
	writefln("Rom mapper: %03d", rom.mapperNo);
	rom.mirroring = (rom.flags6 & 0x1) ? Mirror.VERT : Mirror.HORIZ;
	writefln("Rom nametable mirroring is %s", rom.mirroring);
	rom.hasPrgRam = (rom.flags6 & 0x2) == 1;
	writefln("Rom has PRG RAM: %s", rom.hasPrgRam);
	rom.hasTrainer = (rom.flags6 & 0x4) == 1;
	writefln("Rom has 512-byte trainer: %s", rom.hasTrainer);
	rom.hasFourScreen = (rom.flags6 & 0x8) == 1;
	writefln("Rom has four-screen: %s", rom.hasFourScreen);
	int romPtr = 16;
	auto prgRomFile = File("prgRom", "w");
	if (rom.hasTrainer) {
		rom.trainer = romContents[romPtr..romPtr+512];
		romPtr += 512;
	}
	foreach (i; 0..rom.prgRomSize) {
		rom.prgRom ~= romContents[romPtr..romPtr+16384];
		prgRomFile.rawWrite(romContents[romPtr..romPtr+16384]);
		romPtr += 16384;
	}
	foreach (i; 0..rom.chrRomSize) {
		rom.chrRom ~= romContents[romPtr..romPtr+8192];
		romPtr += 8192;
	}
	if (romPtr < romContents.length) {
		writefln("Warning: unprocessed data at end of ROM (%d bytes).", romContents.length - romPtr);
	} else {
		writeln("Read entire ROM successfully.");
	}
	prgRomFile.close();
	return rom;
}
void mapRom(NESRom rom, ref Memory mem) {
	if (rom.mapperNo == 0) {
		ubyte prgRead(ushort addr) {
			return rom.prgRom[(addr - 0x8000) >> 14][(addr - 0x8000) & 0x3FFF];
		}
		void cannotWrite(ushort addr, ubyte value) {
			throw new RomWriteException(format!"Can't write to read-only memory at address %#04x."(addr));
		}
		mem.createMap(0x8000, 0xFFFF, &prgRead, &cannotWrite);
	}
}


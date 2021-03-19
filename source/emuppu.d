module emuppu;
import arsd.simpledisplay;
import nesrom;
import emucpu;
import instruction: enableDbg;
import std.format;
import std.stdio;

struct RGBColor {
	ubyte red;
	ubyte blue;
	ubyte green;
}
uint[0x40] nesPalette;
void initPalette() {
	nesPalette = [0x7C7C7C, 0x0000FC, 0x0000BC, 0x4428BC, 0x940084, 0xA80020, 0xA81000, 0x881400, 0x503000, 0x007800, 0x006800, 0x005800, 0x004058, 0x000000, 0x000000, 0x000000, 0xBCBCBC, 0x0078F8, 0x0058F8, 0x6844FC, 0xD800CC, 0xE40058, 0xF83800, 0xE45C10, 0xAC7C00, 0x00B800, 0x00A800, 0x00A844, 0x008888, 0x000000, 0x000000, 0x000000, 0xF8F8F8, 0x3CBCFC, 0x6888FC, 0x9878F8, 0xF878F8, 0xF85898, 0xF87858, 0xFCA044, 0xF8B800, 0xB8F818, 0x58D854, 0x58F898, 0x00E8D8, 0x787878, 0x000000, 0x000000, 0xFCFCFC, 0xA4E4FC, 0xB8B8F8, 0xD8B8F8, 0xF8B8F8, 0xF8A4C0, 0xF0D0B0, 0xFCE0A8, 0xF8D878, 0xD8F878, 0xB8F8B8, 0xB8F8D8, 0x00FCFC, 0xF8D8F8, 0x000000, 0x000000];
}
struct EmuPPU {
	SimpleWindow screen;
	bool vblanking;
	bool nmiOnVblank;
	bool nmiOccurred;
	bool largeSprites;
	bool useRightBGTable;
	bool useRightSprTable;
	bool verticalAddrInc;
	ubyte nametableIdx;
	ushort ppuAddress;
	ubyte oamAddress;
	ubyte horizScroll;
	ubyte vertScroll;
	bool dispSprites;
	bool dispBG;
	bool dispLeftSprites;
	bool dispLeftBG;
	bool sprZeroHit;
	bool sprOverflow;
	bool scrollWriteState;
	bool addrWriteState;
	Mirror mirroring;
	Memory ppuMem;
	char[] patternTable;
	ubyte[1024][2] nameTables;
	ubyte[32] palette;
	ubyte[256] oam;
	this(NESRom rom) {
		screen = new SimpleWindow(512, 480, "Gnemulator NES emulator");
		mirroring = rom.mirroring;
		ppuMem = Memory();
		patternTable = rom.chrRom[0];
		ubyte ptRead(ushort addr) {
			return cast(ubyte)(patternTable[addr]);
		}
		void cannotWrite(ushort addr, ubyte value) {
			throw new RomWriteException(format!"Can't write to PPU read-only memory at address %#04x."(addr));
		}
		ubyte ntRead(ushort addr) {
			auto inTable = addr & 1023;
			auto tableNum = (addr % 0x1000) >> 10;
			if (mirroring == Mirror.HORIZ) {
				tableNum = (tableNum & 2) ? 1 : 0;
			} else {
				tableNum &= 1;
			}
			return nameTables[tableNum][inTable];
		}
		void ntWrite(ushort addr, ubyte value) {
			auto inTable = addr & 1023;
			auto tableNum = (addr % 0x1000) >> 10;
			if (mirroring == Mirror.HORIZ) {
				tableNum = (tableNum & 2) ? 1 : 0;
			} else {
				tableNum &= 1;
			}
			nameTables[tableNum][inTable] = value;
		}
		ubyte palRead(ushort addr) {
			return palette[addr - 0x3F00];
		}
		void palWrite(ushort addr, ubyte value) {
			palette[addr - 0x3F00] = value;
		}
		void bgColWrite(ushort addr, ubyte value) {
			palette[0x10] = value;
		}
		ubyte bgColRead(ushort addr) {
			return palette[0x10];
		}
		ppuMem.createMap(0x0000, 0x1FFF, &ptRead, &cannotWrite);
		ppuMem.createMap(0x2000, 0x2FFF, &ntRead, &ntWrite);
		ppuMem.createMap(0x3000, 0x3EFF, &ntRead, &ntWrite);
		ppuMem.createMap(0x3F00, 0x3F00, &bgColRead, &bgColWrite);
		ppuMem.createMap(0x3F01, 0x3F1F, &palRead, &palWrite);
		ppuMem.label = "PPU";
		nmiOnVblank = false;
		scrollWriteState = false;
		addrWriteState = false;
	}
	void ppuCtrl(ubyte value, ref EmuCPU cpu) {
		auto prevNmi = nmiOnVblank;
		nmiOnVblank = (value & 0x80) != 0;
		if (!prevNmi && nmiOnVblank && nmiOccurred) {
			cpu.triggerInterrupt(IntType.NMI);
		}
		largeSprites = (value & 0x20) != 0;
		useRightBGTable = (value & 0x10) != 0;
		useRightSprTable = (value & 0x8) != 0;
		verticalAddrInc = (value & 0x4) != 0;
		nametableIdx = (value & 0x3);
	}
	void ppuMask(ubyte value) {
		dispSprites = (value & 0x10) != 0;
		dispBG = (value & 0x8) != 0;
		dispLeftSprites = (value & 0x4) != 0;
		dispLeftBG = (value & 0x2) != 0;
	}
	ubyte ppuStatus() {
		auto retValue = ((nmiOccurred ? 1 : 0) << 7) + ((sprZeroHit ? 1 : 0) << 6) + ((sprOverflow ? 1 : 0) << 5);
		nmiOccurred = false;
		return cast(ubyte)(retValue);
	}
	void oamAddr(ubyte value) {
		oamAddress = value;
	}
	void oamData(ubyte value) {
		oam[oamAddress] = value;
	}
	void ppuScroll(ubyte value) {
		if (scrollWriteState) {
			vertScroll = value;
		} else {
			horizScroll = value;
		}
		scrollWriteState = !scrollWriteState;
	}
	void ppuAddr(ubyte value) {
		if (!addrWriteState) {
			// writefln("ppuAddr HIGH: %02x", value);
			ppuAddress = cast(ushort)((ppuAddress & 0xFF) + (value << 8));
		} else {
			// writefln("ppuAddr LOW:  %02x", value);
			ppuAddress = cast(ushort)((ppuAddress & 0xFF00) + value);
		}	
		addrWriteState = !addrWriteState;
	}
	void ppuData(ubyte value) {
		ppuMem[ppuAddress] = value;
		ppuAddress += verticalAddrInc ? 32 : 1;
	}
	void drawFrame(ref EmuCPU cpu) {
		nmiOccurred = false;
		auto writer = screen.draw();
		writer.clear();
		auto bgCol = colorFor(palette[0x10]);
		writer.fillColor = Color(cast(int)(bgCol.red), cast(int)(bgCol.green), cast(int)(bgCol.blue));
		writer.drawRectangle(Point(0, 0), screen.width, screen.height);
		drawBackground();		
		nmiOccurred = true;
		if (nmiOnVblank) {
			cpu.triggerInterrupt(IntType.NMI);
		}
	}
	void drawPix(ubyte xPos, ubyte yPos, RGBColor col) {
		auto writer = screen.draw();
		writer.outlineColor = Color(cast(int)(col.red), cast(int)(col.green), cast(int)(col.blue));
		writer.drawRectangle(Point(xPos*2, yPos*2), 2, 2);
	}
	void drawTile(ubyte xPos, ubyte yPos, ubyte tileIdx, ubyte paletteBaseAddr, bool table) {
		foreach(i; 0..8) {
			ubyte lowPlane = ppuMem[cast(ushort)(((table ? 1 : 0) << 12) + (tileIdx << 4) + (0 << 3) + i)];
			ubyte highPlane = ppuMem[cast(ushort)(((table ? 1 : 0) << 12) + (tileIdx << 4) + (1 << 3) + i)];
			foreach(j; 0..8) {
				ubyte col = ((lowPlane & (1 << (7 - j))) == 0 ? 0 : 1) + (((highPlane & (1 << (7 - j))) == 0 ? 0 : 1) << 1);
				if (col == 0) continue;
				drawPix(cast(ubyte)(xPos + j), cast(ubyte)(yPos + i), colorFor(palette[paletteBaseAddr+col-1]));
			}
		}
	}
	void drawBackground() {
		foreach(i; 0..30) {
			foreach(j; 0..32) {
				//auto sai = i + (vertScroll >> 3)
				auto ntEntry = nameTables[0][32 * i + j];
				auto atEntry = nameTables[0][960 + ((i >> 2) << 3) + (j >> 2)];
				auto atBitsPos = (((i & 0x2) << 1) + (j & 0x2)) >> 1;
				ubyte palNum;
				switch (atBitsPos) {
					case 0:
						palNum = atEntry & 0x3;
						break;
					case 1:
						palNum = (atEntry >> 2) & 0x3;
						break;
					case 2:
						palNum = (atEntry >> 4) & 0x3;
						break;
					case 3:
						palNum = (atEntry >> 6) & 0x3;
						break;
					default:
						assert(0, "This text should never appear. What will I do if it does?");
				}
				drawTile(cast(ubyte)(j * 8), cast(ubyte)(i * 8), ntEntry, cast(ubyte)(0x01 + palNum*4), useRightBGTable);
			}
		}
	}
	ubyte ppuCtrlRead() {
		return cast(ubyte)(((nmiOnVblank ? 1 : 0) << 7) + ((largeSprites ? 1 : 0) << 5) + ((useRightBGTable ? 1 : 0) << 4) + ((useRightSprTable ? 1 : 0) << 3) + ((verticalAddrInc ? 1 : 0) << 2) + nametableIdx);
	}
	ubyte oamDataRead() {
		auto retValue = oam[oamAddress];
		return retValue;
	}
	ubyte ppuDataRead() {
		auto retValue = ppuMem[ppuAddress];
		ppuAddress += verticalAddrInc ? 32 : 1;
		return retValue;
	}
}
RGBColor colorFor(ubyte nesColor) {
	auto rawColor = nesPalette[nesColor & 0x3F];
	auto rgb = RGBColor();
	rgb.red = cast(ubyte)(rawColor >> 16);
	rgb.green = cast(ubyte)((rawColor >> 8) & 0xFF);
	rgb.blue = cast(ubyte)(rawColor & 0xFF);
	return rgb;
}

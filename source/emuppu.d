module emuppu;
import arsd.simpledisplay;
import nesrom;
import emucpu;
import instruction: enableDbg;
import std.format;
import std.stdio;
import std.datetime.stopwatch;

struct RGBColor {
	ubyte red;
	ubyte blue;
	ubyte green;
}
struct PixelColor {
	RGBColor color;
	FromWhere where;
}
enum FromWhere {
	BGCOL = 0, BACKGROUND = 1, BEHIND = 2, INFRONT = 3
}
uint[0x40] nesPalette;
void initPalette() {
	nesPalette = [0x7C7C7C, 0x0000FC, 0x0000BC, 0x4428BC, 0x940084, 0xA80020, 0xA81000, 0x881400, 0x503000, 0x007800, 0x006800, 0x005800, 0x004058, 0x000000, 0x000000, 0x000000, 0xBCBCBC, 0x0078F8, 0x0058F8, 0x6844FC, 0xD800CC, 0xE40058, 0xF83800, 0xE45C10, 0xAC7C00, 0x00B800, 0x00A800, 0x00A844, 0x008888, 0x000000, 0x000000, 0x000000, 0xF8F8F8, 0x3CBCFC, 0x6888FC, 0x9878F8, 0xF878F8, 0xF85898, 0xF87858, 0xFCA044, 0xF8B800, 0xB8F818, 0x58D854, 0x58F898, 0x00E8D8, 0x787878, 0x000000, 0x000000, 0xFCFCFC, 0xA4E4FC, 0xB8B8F8, 0xD8B8F8, 0xF8B8F8, 0xF8A4C0, 0xF0D0B0, 0xFCE0A8, 0xF8D878, 0xD8F878, 0xB8F8B8, 0xB8F8D8, 0x00FCFC, 0xF8D8F8, 0x000000, 0x000000];
}
struct EmuPPU {
	SimpleWindow screen;
	PixelColor[256][240] pixelBuffer;
	PixelColor[256][240] oldPixelBuf;
	FromWhere curWhere;
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
	bool onSpriteZero;
	Mirror mirroring;
	Memory ppuMem;
	char[] patternTable;
	ubyte[1024][2] nameTables;
	ubyte[32] palette;
	ubyte[256] oam;
	ubyte ppuReadBuffer;
	this(NESRom rom) {
		screen = new SimpleWindow(512, 480, "Gnemulator NES emulator");
		mirroring = rom.mirroring;
		ppuMem = Memory();
		patternTable = rom.chrRom[0];
		ubyte ptRead(ushort addr) {
			return cast(ubyte)(patternTable[addr]);
		}
		void cannotWrite(ushort addr, ubyte value) {
			// throw new RomWriteException(format!"Can't write to PPU read-only memory at address %#04x."(addr));
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
		oam[oamAddress++] = value;
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
		sprZeroHit = false; 
		auto bgCol = PixelColor(colorFor(palette[0x10]), FromWhere.BGCOL);
		foreach (row; 0..240) {
			pixelBuffer[row][] = bgCol;
		}
		auto scanlineTimer = StopWatch(AutoStart.yes);
		foreach (ubyte scanline; 0..240) {
			curWhere = FromWhere.BACKGROUND;
			drawBackground(scanline);
			spriteRendering(scanline);
			nmiOccurred = scanline == 239;
			while (scanlineTimer.peek() < dur!"usecs"(65)) {
				cpu.step();
			}
			
			scanlineTimer.reset();
		}
		auto writer = screen.draw();
		foreach (xPos; 0..256) {
			foreach(yPos; 0..240) {
				auto col = pixelBuffer[yPos][xPos];
				if (col.color == oldPixelBuf[yPos][xPos].color) continue;
				writer.outlineColor = Color(cast(int)(col.color.red), cast(int)(col.color.green), cast(int)(col.color.blue));
				writer.drawRectangle(Point(xPos*2, yPos*2), 2, 2);
			}
		}
		foreach(row; 0..240) {
			oldPixelBuf[row][] = pixelBuffer[row];
		}
		if (nmiOnVblank) {
			cpu.triggerInterrupt(IntType.NMI);
		}
	}
	void drawPix(ubyte xPos, ubyte yPos, RGBColor col) {
		if (onSpriteZero && pixelBuffer[yPos][xPos].where == FromWhere.BACKGROUND) sprZeroHit = true;
		if (cast(int)curWhere < cast(int)pixelBuffer[yPos][xPos].where) return;
		pixelBuffer[yPos][xPos] = PixelColor(col, curWhere);
	}
	void drawTile(ubyte xPos, ubyte yPos, ubyte tileIdx, ubyte paletteBaseAddr, bool table, byte whichSliver = -1, bool flipHoriz = false, bool flipVert = false) {
		foreach(baseI; 0..8) {
			ubyte i = cast(ubyte)(flipVert ? (7 - baseI) : baseI);
			if (whichSliver != -1 && baseI != whichSliver) continue;
			ubyte lowPlane = ppuMem[cast(ushort)(((table ? 1 : 0) << 12) + (tileIdx << 4) + (0 << 3) + i)];
			ubyte highPlane = ppuMem[cast(ushort)(((table ? 1 : 0) << 12) + (tileIdx << 4) + (1 << 3) + i)];
			foreach(baseJ; 0..8) {
				ubyte j = cast(ubyte)(flipHoriz ? (7 - baseJ) : baseJ);
				ubyte col = ((lowPlane & (1 << (7 - j))) == 0 ? 0 : 1) + (((highPlane & (1 << (7 - j))) == 0 ? 0 : 1) << 1);
				if (col == 0) continue;
				drawPix(cast(ubyte)(xPos + baseJ), cast(ubyte)(yPos + baseI), colorFor(palette[paletteBaseAddr+col-1]));
			}
		}
	}
	void drawBackground(ubyte scanline) {
		if (!dispBG) return;
		ubyte i = scanline >> 3;
		ubyte sliver = scanline & 7;
		foreach(j; 0..32) {
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
			drawTile(cast(ubyte)(j << 3), cast(ubyte)(i << 3), ntEntry, cast(ubyte)(0x01 + (palNum << 2)), useRightBGTable, sliver);
		}
	}
	void spriteRendering(ubyte scanline) {
		if (!dispSprites) return;
		ubyte[8] foundSprites;
		ubyte numFoundSprites = 0;
		foreach(ubyte whichSprite; 0..64) {
			// writefln("Scanline: %d, on sprite %d and our sprite's top is at %d", scanline, whichSprite, oam[whichSprite << 2]);
			if (oam[whichSprite << 2] + (largeSprites ? 16 : 8) > scanline && oam[whichSprite << 2] <= scanline) {
				// writeln("hit!");
				if (numFoundSprites == 8) {
					// writefln("Warning: sprite overflow is pretty much unimplemented but we're on sprite %d", whichSprite);
					sprOverflow = true;
					// throw new Exception("bleh");
				} else {
					foundSprites[numFoundSprites++] = whichSprite;
				}
			}
		}
		foreach(ubyte foundIdx; 0..numFoundSprites) {
			ubyte whichSprite = foundSprites[foundIdx];
			ubyte spriteX = oam[(whichSprite << 2) + 3];
			ubyte spriteY = oam[whichSprite << 2];
			ubyte tileIdx = oam[(whichSprite << 2) + 1];
			ubyte sprPalNum = oam[(whichSprite << 2) + 2] & 3;
			bool sprFlipVert = (oam[(whichSprite << 2) + 2] & 0x80) != 0;
			bool sprFlipHoriz = (oam[(whichSprite << 2) + 2] & 0x40) != 0;
			curWhere = cast(bool)(oam[(whichSprite << 2) + 2] & 32) ? FromWhere.BEHIND : FromWhere.INFRONT;
			if (whichSprite == 0) onSpriteZero = true;
			if (!largeSprites || (scanline - spriteY) < 8) {
				drawTile(spriteX, spriteY, largeSprites ? tileIdx & 0xFE : tileIdx, cast(ubyte)(0x11 + (sprPalNum << 2)), largeSprites ? (tileIdx & 1) == 1 : useRightSprTable, cast(byte)(scanline - spriteY), sprFlipHoriz, sprFlipVert);
			} else {
				drawTile(spriteX, cast(ubyte)(spriteY + 8), tileIdx | 1, cast(ubyte)(0x11 + (sprPalNum << 2)), (tileIdx & 1) == 1, cast(byte)(scanline - spriteY - 8), sprFlipHoriz, sprFlipVert);
			}
			onSpriteZero = false;
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
		auto oldAddress = ppuAddress;
		ppuAddress += verticalAddrInc ? 32 : 1;
		if (oldAddress < 0x3F00) {
			auto bufVal = ppuReadBuffer;
			ppuReadBuffer = ppuMem[oldAddress];
			return bufVal;
		}
		return ppuMem[oldAddress];
	}
	void oamDma(ubyte page, EmuCPU cpu) {
		foreach(ubyte idx; 0..256) {
			oam[idx] = cpu.mem[cast(ushort)((page << 8) + idx)];
		}
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

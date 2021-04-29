module emucpu;
import instruction : Instruction, enableDbg, DEBUGGING;
import std.format: format;
import std.algorithm;
import std.array;
import std.stdio;
import std.typecons;

enum CPUFlags {
	C = 1 << 0,
	Z = 1 << 1,
	I = 1 << 2,
	D = 1 << 3,
	B = 1 << 4,
	unused = 1 << 5,
	V = 1 << 6,
	N = 1 << 7
}
enum IntType {
	NMI,
	RESET,
	IRQ
}
enum UNMAPPED_VAL = 0xEE;
enum INIT_PC = 0x0000;
enum INIT_STACKPTR = 0xFF;
enum STACK_PAGE = 0x01;
ushort debugAt = 0xEF99;
enum INTERACTIVE_DBG = true;
class DecodeException : Exception {
	this(string msg) {
		super(msg);
	}
}
struct MemoryMap {
	ushort starting;
	ushort ending;
	ubyte delegate(ushort) readFx;
	void delegate(ushort, ubyte) writeFx;
}
struct Memory {
	MemoryMap[] maps;
	ushort[] watchPts;
	EmuCPU* cpu;
	string label;
	bool silenceUnmapped;
	bool silenceWatch;
	ubyte opIndex(ushort idx) {
		if (!silenceWatch && watchPts.canFind(idx)) {
			writefln("WATCHPOINT: %s read from %04x from %04x!", label, idx, (*cpu).programCtr);
		}
		foreach (map; maps) {
			if (idx >= map.starting && idx <= map.ending) {
				return map.readFx(idx);
			}
		}
		if (silenceUnmapped) return UNMAPPED_VAL;
		writefln!"(%s READ from %04x) Warning: memory address %#04x is unmapped!"(label, (*cpu).programCtr, idx);
		return UNMAPPED_VAL;
	}
	ubyte opIndexAssign(ubyte value, ushort idx) {
		if (!silenceWatch && watchPts.canFind(idx)) {
			writefln("WATCHPOINT: %s wrote to %04x the value %02x from %04x!", label, idx, value, (*cpu).programCtr);
		}
		bool unmapped = true;
		foreach (map; maps) {
			if (idx >= map.starting && idx <= map.ending) {
				map.writeFx(idx, value);
				unmapped = false;
			}
		}
		if (unmapped && !silenceUnmapped) {
			writefln!"(%s WRITE from %04x) Warning: memory address %#04x is unmapped!"(label, (*cpu).programCtr, idx);
		}
		return value;
	}
	void createMap(ushort startAt, ushort endAt, ubyte delegate(ushort) readTo, void delegate(ushort, ubyte) writeFrom) {
		maps ~= MemoryMap(startAt, endAt, readTo, writeFrom);
	}
}
struct EmuCPU {
	ubyte flags;
	ushort programCtr;
	ushort lastPc;
	ubyte accumulator;
	ubyte xReg;
	ubyte yReg;
	ubyte stackPtr;
	ulong numIns;
	Instruction[] instructionSet;
	Memory mem;
	ulong steps;
	Tuple!(Instruction, ushort, ushort)[] lastInstructions;
	Instruction decode(ubyte opcode) {
		auto matches = filter!(a => a.opcode == opcode)(instructionSet).array;
		if (matches.length > 1) {
			throw new DecodeException(format!"%d instructions found for opcode %#x"(matches.length, opcode));
		} else if (matches.length == 0) {
			throw new DecodeException(format!"No instructions found for opcode %#x"(opcode));
		} else {
			return matches[0];
		}
	}
	void step() {
		if ((programCtr == debugAt || DEBUGGING) && (programCtr + 1 == programCtr)) {
			if (INTERACTIVE_DBG) {
				foreach(i; 0..8) {
					writefln("%s %s %04x at %04x", lastInstructions[i][0], lastInstructions[i][0].addressing, lastInstructions[i][1], lastInstructions[i][2]);
				}
				dump();
				DEBUGGING = readln() != "c\n";
			} else {
				enableDbg();
			}
		}
		auto decodeOp = mem[programCtr];
		auto ins = decode(decodeOp);
		if (lastInstructions.length < 8) {
			lastInstructions ~= tuple(ins, this.operandWord, programCtr);
		} else {
			lastInstructions ~= tuple(ins, this.operandWord, programCtr);
			lastInstructions = lastInstructions[1..$];
		}
		// writeln(ins);
		ins.executeDebug(this);
		lastPc = programCtr;
		programCtr += ins.size;
		steps++;
		
		// writefln("Performing CPU step %d", numIns++);
	}
	void setFlag(ubyte flag) {
		flags |= flag;
	}
	void clearFlag(ubyte flag) {
		flags &= cast(ubyte)(~cast(int)flag);
	}
	void toggleFlag(ubyte flag) {
		flags ^= flag;
	}
	bool isSet(ubyte flag) {
		return (flags & flag) != 0;
	}
	void chkZeroFlag(ubyte result) {
		if (result == 0) {
			setFlag(CPUFlags.Z);
		} else {
			clearFlag(CPUFlags.Z);
		}
	}
	void chkNegFlag(ubyte result) {
		if (result & 0x80) {
			setFlag(CPUFlags.N);
		} else {
			clearFlag(CPUFlags.N);
		}
	}
	void chkCarryFlagSub(ubyte inp1, ubyte inp2) {
		if (inp2 <= inp1) {
			setFlag(CPUFlags.C);
		} else {
			clearFlag(CPUFlags.C);
		}
	}
	void chkOverflowFlagSub(ubyte inp1, ubyte inp2, ubyte result) {
		if (inp1 > inp2 && result & 0x80 || inp1 < inp2 && !(result & 0x80)) {
			setFlag(CPUFlags.V);
		} else {
			clearFlag(CPUFlags.V);
		}
	}
	void chkCarryFlagAdd(ubyte inp1, ubyte inp2, ubyte optional = 0) {
		if (inp1 + inp2 + optional > 0xFF) {
			setFlag(CPUFlags.C);
		} else {
			clearFlag(CPUFlags.C);
		}
	}
	void chkOverflowFlagAdd(ubyte inp1, ubyte inp2, ubyte result) {
		if (inp1 & 0x80 && inp2 & 0x80 && !(result & 0x80) || !(inp1 & 0x80) && !(inp2 & 0x80) && result & 0x80) {
			setFlag(CPUFlags.V);
		} else {
			clearFlag(CPUFlags.V);
		}
	}
	this(Instruction[] insSet) {
		programCtr = INIT_PC;
		accumulator = 0x00;
		xReg = 0x00;
		yReg = 0x00;
		stackPtr = INIT_STACKPTR;
		mem = Memory();
		mem.cpu = &this;
		mem.label = "CPU";
		instructionSet = insSet;
		flags = 0x00;
	}
	@property ubyte operandByte() {
		return mem[cast(ushort)(programCtr + 1)];
	}
	@property ushort operandWord() {
		return cast(ushort)((mem[cast(ushort)(programCtr + 2)] << 8) + mem[cast(ushort)(programCtr + 1)]);
	}
	void dumpPage(ubyte page) {
		writefln("Page at %02x:", page);
		foreach(i; 0..16) {
			writef("%04x: ", page*0x100 + i*0x10);
			foreach(j; 0..16) {
				writef("%02x ", mem[cast(ushort)(page*0x100 + i*0x10 + j)]);
			}
			writeln();
		}
	}
	void pushStack(ubyte value) {
		// writefln("Pushed %02x to the stack; sp = %02x, addr of %04x", value, stackPtr, cast(ushort)((STACK_PAGE << 8) + stackPtr));
		mem[cast(ushort)((STACK_PAGE << 8) + stackPtr)] = value;
		stackPtr--;
	}
	ubyte pullStack() {
		stackPtr++;
		// writefln("Got %02x from the stack; sp = %02x, addr of %04x", mem[cast(ushort)((STACK_PAGE << 8) + stackPtr)], stackPtr, cast(ushort)((STACK_PAGE << 8) + stackPtr));
		return mem[cast(ushort)((STACK_PAGE << 8) + stackPtr)];
	}
	void dump() {
		writefln("Program counter: %04x\nAccumulator: %02x\nXreg: %02x\nYreg: %02x\nStack ptr: %02x", programCtr, accumulator, xReg, yReg, stackPtr);
		writefln("Flags: %s%s%s%s%s%s%s%s", isSet(CPUFlags.C) ? "C" : " ", isSet(CPUFlags.Z) ? "Z" : " ", isSet(CPUFlags.I) ? "I" : " ", isSet(CPUFlags.D) ? "D" : " ", isSet(CPUFlags.B) ? "B" : " ", isSet(CPUFlags.unused) ? "?" : " ", isSet(CPUFlags.V) ? "V" : " ", isSet(CPUFlags.N) ? "N" : " ");
		try {		
			writefln("Last instruction at %04x: %s / %02x / %02x", lastPc, decode(mem[lastPc]), mem[cast(ushort)(lastPc+1)], mem[cast(ushort)(lastPc+2)]);				
		} catch (DecodeException) {
			writeln("Last instruction couldn't be decoded.");
		}		
		dumpPage(0);
		dumpPage(3);
	}
	void triggerInterrupt(IntType interrupt) {
		switch (interrupt) {
			case IntType.NMI:
				pushStack(cast(ubyte)((programCtr) >> 8));
				pushStack((programCtr) & 0xFF);
				pushStack(flags);
				// writefln("Non-masking interrupt occurred while program was at %04x", programCtr);
				programCtr = (mem[0xFFFB] << 8) + mem[0xFFFA];
				break;
			case IntType.RESET:
				programCtr = (mem[0xFFFD] << 8) + mem[0xFFFC];
				break;
			case IntType.IRQ:
				if (isSet(CPUFlags.I)) return;
				pushStack(cast(ubyte)((programCtr+2) >> 8));
				pushStack((programCtr+2) & 0xFF);
				pushStack(flags);
				programCtr = (mem[0xFFFF] << 8) + mem[0xFFFE];
				break;
			default:
				assert(0, "This shouldn't be ever seen...");
		}
		// writefln("%s caused the program to jump to %04x", interrupt, programCtr);
	}
}

module instruction;
import emucpu : EmuCPU, CPUFlags, IntType;
import std.format : format;
import std.typecons : BitFlags;
import std.stdio;
bool DEBUGGING = false;
void enableDbg() {
	DEBUGGING = true;
}
enum AddrMode {
	ACCUMULATOR,
	ABSOLUTE,
	ABSX,
	ABSY,
	IMMEDIATE,
	/* various forms of implied */
	SNONE,
	INDIRECT,
	INDX,
	INDY,
	RELATIVE,
	ZEROPAGE,
	ZPAGEX,
	ZPAGEY
}
class AddressModeException : Exception {
	this(string msg) {
		super(msg);
	}
}
class Instruction {
	ubyte opcode;
	ubyte size;
	ubyte cycles;
	AddrMode addressing;
	ubyte getAddr(ref EmuCPU cpu) {
		switch (addressing) {
			case AddrMode.ZEROPAGE:
				return cpu.mem[cpu.operandByte];
			case AddrMode.ZPAGEX:
				return cpu.mem[cast(ushort)(cpu.operandByte + cpu.xReg)];
			case AddrMode.IMMEDIATE:
				return cpu.operandByte;
			case AddrMode.ABSOLUTE:
				return cpu.mem[cpu.operandWord];
			case AddrMode.ABSX:
				cpu.chkCarryFlagAdd(cpu.operandByte, cpu.xReg);
				return cpu.mem[cast(ushort)(cpu.operandWord + cpu.xReg)];
			case AddrMode.ABSY:
				cpu.chkCarryFlagAdd(cpu.operandByte, cpu.yReg);
				return cpu.mem[cast(ushort)(cpu.operandWord + cpu.yReg)];
			case AddrMode.INDX:
				return cpu.mem[cast(ushort)((cpu.mem[cast(ushort)(cpu.operandByte + cpu.xReg + 1)] << 8) + cpu.mem[cast(ushort)(cpu.operandByte + cpu.xReg)])];
			case AddrMode.INDY:
				return cpu.mem[cast(ushort)((cpu.mem[cast(ushort)(cpu.operandByte + 1)] << 8) + cpu.mem[cast(ushort)(cpu.operandByte)] + cpu.yReg)];
			case AddrMode.ACCUMULATOR:
				return cpu.accumulator;
			case AddrMode.RELATIVE:
				return cpu.operandByte;
			case AddrMode.INDIRECT:
				return cpu.mem[cast(ushort)((cpu.mem[cast(ushort)(cpu.operandByte + 1)] << 8) + cpu.mem[cast(ushort)(cpu.operandByte)])];
			default:
				throw new AddressModeException(format!"Reading from addressing mode %s not supported"(addressing));
		}
	}
	void putAddr(ref EmuCPU cpu, ubyte value) {
		switch (addressing) {
			case AddrMode.ZEROPAGE:
				cpu.mem[cpu.operandByte] = value;
				break;
			case AddrMode.ZPAGEX:
				cpu.mem[cast(ushort)(cpu.operandByte + cpu.xReg)] = value;
				break;
			case AddrMode.ABSOLUTE:
				cpu.mem[cpu.operandWord] = value;
				break;
			case AddrMode.ABSX:
				cpu.mem[cast(ushort)(cpu.operandWord + cpu.xReg)] = value;
				break;
			case AddrMode.ABSY:
				cpu.mem[cast(ushort)(cpu.operandWord + cpu.yReg)] = value;
				break;
			case AddrMode.INDX:
				cpu.mem[cast(ushort)((cpu.mem[cast(ushort)(cpu.operandByte + cpu.xReg + 1)] << 8) + cpu.mem[cast(ushort)(cpu.operandByte + cpu.xReg)])] = value;
				break;
			case AddrMode.INDY:
				cpu.mem[cast(ushort)((cpu.mem[cast(ushort)(cpu.operandByte + 1)] << 8) + cpu.mem[cast(ushort)(cpu.operandByte)] + cpu.yReg)] = value;
				break;
			case AddrMode.ACCUMULATOR:
				cpu.accumulator = value;
				break;
			default:
				throw new AddressModeException(format!"Writing to addressing mode %s not supported"(addressing));
		}
	}
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		opcode = iOpcode;
		size = iSize;
		cycles = iCycles;
		addressing = iAddr;
	}
	void executeDebug(ref EmuCPU cpu) {
		if (DEBUGGING && !(this.opcode == 0x4C && cpu.operandWord == cpu.programCtr)) {
			writefln("%04x: %02x - %s %s", cpu.programCtr, opcode, this, addressing);
		}
		execute(cpu);
	}
	abstract void execute(ref EmuCPU cpu);
}
class AdcInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp1 = cpu.accumulator;
		ubyte inp2 = getAddr(cpu);
		ubyte result = cast(ubyte)(inp1 + inp2 + (cpu.isSet(CPUFlags.C) ? 1 : 0));
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		cpu.chkCarryFlagAdd(inp1, inp2);
		cpu.chkOverflowFlagAdd(inp1, inp2, result);
		cpu.accumulator = result;
	}
}
class AndInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp1 = cpu.accumulator;
		ubyte inp2 = getAddr(cpu);
		ubyte result = cast(ubyte)(inp1 & inp2);
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		cpu.accumulator = result;
	}
}
class AslInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp = getAddr(cpu);
		ubyte result = cast(ubyte)(inp << 1);
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		if (inp & 0x80) {
			cpu.setFlag(CPUFlags.C);
		} else {
			cpu.clearFlag(CPUFlags.C);
		}
		putAddr(cpu, result);
	}
}
class BccInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (!cpu.isSet(CPUFlags.C)) {
			cpu.programCtr += cast(byte)(getAddr(cpu));
			if (DEBUGGING) {
				writefln("Branch taken");
			}
		}
	}
}
class BcsInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (cpu.isSet(CPUFlags.C)) {
			cpu.programCtr += cast(byte)(getAddr(cpu));
			if (DEBUGGING) {
				writefln("Branch taken");
			}
		}
	}
}
class BeqInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (cpu.isSet(CPUFlags.Z)) {
			cpu.programCtr += cast(byte)(getAddr(cpu));
			if (DEBUGGING) {
				writefln("Branch taken");
			}
		}
	}
}
class BitInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (getAddr(cpu) & 0x80) {
			cpu.setFlag(CPUFlags.N);
		} else {
			cpu.clearFlag(CPUFlags.N);
		}
		if (getAddr(cpu) & 0x40) {
			cpu.setFlag(CPUFlags.V);
		} else {
			cpu.clearFlag(CPUFlags.V);
		}
		cpu.chkZeroFlag(getAddr(cpu) & cpu.accumulator);
	}
}
class BmiInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (cpu.isSet(CPUFlags.N)) {
			cpu.programCtr += cast(byte)(getAddr(cpu));
			if (DEBUGGING) {
				writefln("Branch taken");
			}
		}
	}
}
class BneInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (!cpu.isSet(CPUFlags.Z)) {
			cpu.programCtr += cast(byte)(getAddr(cpu));
			if (DEBUGGING) {
				writefln("Branch taken");
			}
		}
	}
}
class BplInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (!cpu.isSet(CPUFlags.N)) {
			cpu.programCtr += cast(byte)(getAddr(cpu));
			if (DEBUGGING) {
				writefln("Branch taken");
			}
		}
	}
}
class BrkInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.setFlag(CPUFlags.I);
		cpu.triggerInterrupt(IntType.IRQ);
	}
}
class BvcInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (!cpu.isSet(CPUFlags.V)) {
			cpu.programCtr += cast(byte)(getAddr(cpu));
			if (DEBUGGING) {
				writefln("Branch taken");
			}
		}
	}
}
class BvsInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		if (cpu.isSet(CPUFlags.V)) {
			cpu.programCtr += cast(byte)(getAddr(cpu));
			if (DEBUGGING) {
				writefln("Branch taken");
			}
		}
	}
}
class ClcInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.clearFlag(CPUFlags.C);
	}
}
class CldInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.clearFlag(CPUFlags.D);
	}
}
class CliInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.clearFlag(CPUFlags.I);
	}
}
class ClvInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.clearFlag(CPUFlags.V);
	}
}
class CmpInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp1 = cpu.accumulator;
		ubyte inp2 = getAddr(cpu);
		ubyte result = cast(ubyte)(inp1 - inp2);
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		cpu.chkCarryFlagSub(inp1, inp2);
	}
}
class CpxInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp1 = cpu.xReg;
		ubyte inp2 = getAddr(cpu);
		ubyte result = cast(ubyte)(inp1 - inp2);
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		cpu.chkCarryFlagSub(inp1, inp2);
	}
}
class CpyInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp1 = cpu.yReg;
		ubyte inp2 = getAddr(cpu);
		ubyte result = cast(ubyte)(inp1 - inp2);
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		cpu.chkCarryFlagSub(inp1, inp2);
	}
}
class DecInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = cast(ubyte)(getAddr(cpu) - 1);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		putAddr(cpu, result);
	}
}
class DexInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = cast(ubyte)(cpu.xReg - 1);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		cpu.xReg = result;
	}
}
class DeyInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = cast(ubyte)(cpu.yReg - 1);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		cpu.yReg = result;
	}
}
class EorInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp1 = cpu.accumulator;
		ubyte inp2 = getAddr(cpu);
		ubyte result = cast(ubyte)(inp1 ^ inp2);
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		cpu.accumulator = result;
	}
}
class IncInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = cast(ubyte)(getAddr(cpu) + 1);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		putAddr(cpu, result);
	}
}
class InxInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = cast(ubyte)(cpu.xReg + 1);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		cpu.xReg = result;
	}
}
class InyInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = cast(ubyte)(cpu.yReg + 1);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		cpu.yReg = result;
	}
}
class JmpInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ushort jumpTo;
		if (addressing == AddrMode.ABSOLUTE) {
			jumpTo = cpu.operandWord;
		} else if (addressing == AddrMode.INDIRECT) {
			jumpTo = (cpu.mem[cast(ushort)(cpu.operandWord + 1)] << 8) + cpu.mem[cpu.operandWord];
		} else {
			throw new AddressModeException("Invalid JMP address mode");	
		}
		cpu.programCtr = cast(ushort)(jumpTo - size);
	}
}
class JsrInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ushort jumpTo;
		if (addressing == AddrMode.ABSOLUTE) {
			jumpTo = cpu.operandWord;
		} else if (addressing == AddrMode.INDIRECT) {
			jumpTo = cpu.mem[cpu.operandWord];
		} else {
			throw new AddressModeException("Invalid JMP address mode");	
		}
		cpu.pushStack(cast(ubyte)((cpu.programCtr + 2) >> 8));
		cpu.pushStack((cpu.programCtr + 2) & 0xFF);
		cpu.programCtr = cast(ushort)(jumpTo - size);
	}
}
class LdaInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = getAddr(cpu);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		cpu.accumulator = result;
	}
}
class LdxInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = getAddr(cpu);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		cpu.xReg = result;
	}
}
class LdyInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte result = getAddr(cpu);
		cpu.chkZeroFlag(result);
		cpu.chkNegFlag(result);
		cpu.yReg = result;
	}
}
class LsrInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp = getAddr(cpu);
		ubyte result = cast(ubyte)(inp >> 1);
		cpu.clearFlag(CPUFlags.N);
		cpu.chkZeroFlag(result);
		if (inp & 0x1) {
			cpu.setFlag(CPUFlags.C);
		} else {
			cpu.clearFlag(CPUFlags.C);
		}
		putAddr(cpu, result);
	}
}
class NopInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		//
	}
}
class OraInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp1 = cpu.accumulator;
		ubyte inp2 = getAddr(cpu);
		ubyte result = cast(ubyte)(inp1 | inp2);
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		cpu.accumulator = result;
	}
}
class PhaInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.pushStack(cpu.accumulator);
	}
}
class PhpInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.pushStack(cpu.flags);
	}
}
class PlaInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.accumulator = cpu.pullStack();
	}
}
class PlpInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.flags = cpu.pullStack();
	}
}
class RolInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp = getAddr(cpu);
		ubyte result = cast(ubyte)((inp << 1) + (cpu.isSet(CPUFlags.C) ? 1 : 0));
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		if (inp & 0x80) {
			cpu.setFlag(CPUFlags.C);
		} else {
			cpu.clearFlag(CPUFlags.C);
		}
		putAddr(cpu, result);
	}
}
class RorInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp = getAddr(cpu);
		ubyte result = cast(ubyte)((inp >> 1) + (cpu.isSet(CPUFlags.C) ? 0x80 : 0));
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		if (inp & 0x1) {
			cpu.setFlag(CPUFlags.C);
		} else {
			cpu.clearFlag(CPUFlags.C);
		}
		putAddr(cpu, result);
	}
}
class RtiInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.flags = cpu.pullStack();
		auto lowPc = cpu.pullStack();
		auto highPc = cpu.pullStack();
		cpu.programCtr = cast(ushort)((highPc << 8) + lowPc - size);
	}
}
class RtsInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		auto lowPc = cpu.pullStack();
		auto highPc = cpu.pullStack();
		cpu.programCtr = cast(ushort)((highPc << 8) + lowPc - size + 1);
	}
}
class SbcInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		ubyte inp1 = cpu.accumulator;
		ubyte inp2 = getAddr(cpu);
		ubyte result = cast(ubyte)(inp1 - inp2 - (cpu.isSet(CPUFlags.C) ? 0 : 1));
		cpu.chkNegFlag(result);
		cpu.chkZeroFlag(result);
		cpu.chkCarryFlagAdd(inp1, inp2);
		cpu.chkOverflowFlagAdd(inp1, inp2, result);
		cpu.accumulator = result;
	}
}
class SecInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
			cpu.setFlag(CPUFlags.C);
	}
}
class SedInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
			cpu.setFlag(CPUFlags.D);
	}
}
class SeiInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
			cpu.setFlag(CPUFlags.I);
	}
}
class StaInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		putAddr(cpu, cpu.accumulator);
	}
}
class StxInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		putAddr(cpu, cpu.xReg);
	}
}
class StyInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		putAddr(cpu, cpu.yReg);
	}
}
class TaxInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.xReg = cpu.accumulator;
	}
}
class TayInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.yReg = cpu.accumulator;
	}
}
class TsxInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.xReg = cpu.stackPtr;
	}
}
class TxaInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.accumulator = cpu.xReg;
	}
}
class TxsInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.stackPtr = cpu.xReg;
	}
}
class TyaInstruction : Instruction {
	this(ubyte iOpcode, ubyte iSize, ubyte iCycles, AddrMode iAddr) {
		super(iOpcode, iSize, iCycles, iAddr);
	}
	override void execute(ref EmuCPU cpu) {
		cpu.accumulator = cpu.yReg;
	}
}

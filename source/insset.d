module insset;
import instruction;

Instruction[] getDefaultIS() {
	Instruction[] insSet;
	insSet ~= new AdcInstruction(0x69, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new AdcInstruction(0x65, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new AdcInstruction(0x75, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new AdcInstruction(0x6D, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new AdcInstruction(0x7D, 3, 4, AddrMode.ABSX);
	insSet ~= new AdcInstruction(0x79, 3, 4, AddrMode.ABSY);
	insSet ~= new AdcInstruction(0x61, 2, 6, AddrMode.INDX);
	insSet ~= new AdcInstruction(0x71, 2, 5, AddrMode.INDY);
	insSet ~= new AndInstruction(0x29, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new AndInstruction(0x25, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new AndInstruction(0x35, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new AndInstruction(0x2D, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new AndInstruction(0x3D, 3, 4, AddrMode.ABSX);
	insSet ~= new AndInstruction(0x39, 3, 4, AddrMode.ABSY);
	insSet ~= new AndInstruction(0x21, 2, 6, AddrMode.INDX);
	insSet ~= new AndInstruction(0x31, 2, 5, AddrMode.INDY);
	insSet ~= new AslInstruction(0x0A, 1, 2, AddrMode.ACCUMULATOR);
	insSet ~= new AslInstruction(0x06, 2, 5, AddrMode.ZEROPAGE);
	insSet ~= new AslInstruction(0x16, 2, 6, AddrMode.ZPAGEX);
	insSet ~= new AslInstruction(0x0E, 3, 6, AddrMode.ABSOLUTE);
	insSet ~= new AslInstruction(0x1E, 3, 7, AddrMode.ABSX);
	insSet ~= new BccInstruction(0x90, 2, 2, AddrMode.RELATIVE);
	insSet ~= new BcsInstruction(0xB0, 2, 2, AddrMode.RELATIVE);
	insSet ~= new BeqInstruction(0xF0, 2, 2, AddrMode.RELATIVE);
	insSet ~= new BitInstruction(0x24, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new BitInstruction(0x2C, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new BmiInstruction(0x30, 2, 2, AddrMode.RELATIVE);
	insSet ~= new BneInstruction(0xD0, 2, 2, AddrMode.RELATIVE);
	insSet ~= new BplInstruction(0x10, 2, 2, AddrMode.RELATIVE);
	insSet ~= new BrkInstruction(0x00, 2, 7, AddrMode.SNONE);
	insSet ~= new BvcInstruction(0x50, 2, 2, AddrMode.RELATIVE);
	insSet ~= new BvsInstruction(0x70, 2, 2, AddrMode.RELATIVE);
	insSet ~= new ClcInstruction(0x18, 1, 2, AddrMode.SNONE);
	insSet ~= new CldInstruction(0xD8, 1, 2, AddrMode.SNONE);
	insSet ~= new CliInstruction(0x58, 1, 2, AddrMode.SNONE);
	insSet ~= new ClvInstruction(0xB8, 1, 2, AddrMode.SNONE);
	insSet ~= new CmpInstruction(0xC9, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new CmpInstruction(0xC5, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new CmpInstruction(0xD5, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new CmpInstruction(0xCD, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new CmpInstruction(0xDD, 3, 4, AddrMode.ABSX);
	insSet ~= new CmpInstruction(0xD9, 3, 4, AddrMode.ABSY);
	insSet ~= new CmpInstruction(0xC1, 2, 6, AddrMode.INDX);
	insSet ~= new CmpInstruction(0xD1, 2, 5, AddrMode.INDY);
	insSet ~= new CpxInstruction(0xE0, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new CpxInstruction(0xE4, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new CpxInstruction(0xEC, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new CpyInstruction(0xC0, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new CpyInstruction(0xC4, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new CpyInstruction(0xCC, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new DecInstruction(0xC6, 2, 5, AddrMode.ZEROPAGE);
	insSet ~= new DecInstruction(0xD6, 2, 6, AddrMode.ZPAGEX);
	insSet ~= new DecInstruction(0xCE, 3, 6, AddrMode.ABSOLUTE);
	insSet ~= new DecInstruction(0xDE, 3, 7, AddrMode.ABSX);
	insSet ~= new DexInstruction(0xCA, 1, 2, AddrMode.SNONE);
	insSet ~= new DeyInstruction(0x88, 1, 2, AddrMode.SNONE);
	insSet ~= new EorInstruction(0x49, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new EorInstruction(0x45, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new EorInstruction(0x55, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new EorInstruction(0x4D, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new EorInstruction(0x5D, 3, 4, AddrMode.ABSX);
	insSet ~= new EorInstruction(0x59, 3, 4, AddrMode.ABSY);
	insSet ~= new EorInstruction(0x41, 2, 6, AddrMode.INDX);
	insSet ~= new EorInstruction(0x51, 2, 5, AddrMode.INDY);
	insSet ~= new IncInstruction(0xE6, 2, 5, AddrMode.ZEROPAGE);
	insSet ~= new IncInstruction(0xF6, 2, 6, AddrMode.ZPAGEX);
	insSet ~= new IncInstruction(0xEE, 3, 6, AddrMode.ABSOLUTE);
	insSet ~= new IncInstruction(0xFE, 3, 7, AddrMode.ABSX);
	insSet ~= new InxInstruction(0xE8, 1, 2, AddrMode.SNONE);
	insSet ~= new InyInstruction(0xC8, 1, 2, AddrMode.SNONE);
	insSet ~= new JmpInstruction(0x4C, 3, 3, AddrMode.ABSOLUTE);
	insSet ~= new JmpInstruction(0x6C, 3, 5, AddrMode.INDIRECT);
	insSet ~= new JsrInstruction(0x20, 3, 6, AddrMode.ABSOLUTE);
	insSet ~= new LdaInstruction(0xA9, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new LdaInstruction(0xA5, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new LdaInstruction(0xB5, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new LdaInstruction(0xAD, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new LdaInstruction(0xBD, 3, 4, AddrMode.ABSX);
	insSet ~= new LdaInstruction(0xB9, 3, 4, AddrMode.ABSY);
	insSet ~= new LdaInstruction(0xA1, 2, 6, AddrMode.INDX);
	insSet ~= new LdaInstruction(0xB1, 2, 5, AddrMode.INDY);
	insSet ~= new LdxInstruction(0xA2, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new LdxInstruction(0xA6, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new LdxInstruction(0xB6, 2, 4, AddrMode.ZPAGEY);
	insSet ~= new LdxInstruction(0xAE, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new LdxInstruction(0xBE, 3, 4, AddrMode.ABSY);
	insSet ~= new LdyInstruction(0xA0, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new LdyInstruction(0xA4, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new LdyInstruction(0xB4, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new LdyInstruction(0xAC, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new LdyInstruction(0xBC, 3, 4, AddrMode.ABSX);
	insSet ~= new LsrInstruction(0x4A, 1, 2, AddrMode.ACCUMULATOR);
	insSet ~= new LsrInstruction(0x46, 2, 5, AddrMode.ZEROPAGE);
	insSet ~= new LsrInstruction(0x56, 2, 6, AddrMode.ZPAGEX);
	insSet ~= new LsrInstruction(0x4E, 3, 6, AddrMode.ABSOLUTE);
	insSet ~= new LsrInstruction(0x5E, 3, 7, AddrMode.ABSX);
	insSet ~= new NopInstruction(0xEA, 1, 2, AddrMode.SNONE);
	insSet ~= new OraInstruction(0x09, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new OraInstruction(0x05, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new OraInstruction(0x15, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new OraInstruction(0x0D, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new OraInstruction(0x1D, 3, 4, AddrMode.ABSX);
	insSet ~= new OraInstruction(0x19, 3, 4, AddrMode.ABSY);
	insSet ~= new OraInstruction(0x01, 2, 6, AddrMode.INDX);
	insSet ~= new OraInstruction(0x11, 2, 5, AddrMode.INDY);
	insSet ~= new PhaInstruction(0x48, 1, 3, AddrMode.SNONE);
	insSet ~= new PhpInstruction(0x08, 1, 3, AddrMode.SNONE);
	insSet ~= new PlaInstruction(0x68, 1, 4, AddrMode.SNONE);
	insSet ~= new PlpInstruction(0x28, 1, 4, AddrMode.SNONE);
	insSet ~= new RolInstruction(0x2A, 1, 2, AddrMode.ACCUMULATOR);
	insSet ~= new RolInstruction(0x26, 2, 5, AddrMode.ZEROPAGE);
	insSet ~= new RolInstruction(0x36, 2, 6, AddrMode.ZPAGEX);
	insSet ~= new RolInstruction(0x2E, 3, 6, AddrMode.ABSOLUTE);
	insSet ~= new RolInstruction(0x3E, 3, 7, AddrMode.ABSX);
	insSet ~= new RorInstruction(0x6A, 1, 2, AddrMode.ACCUMULATOR);
	insSet ~= new RorInstruction(0x66, 2, 5, AddrMode.ZEROPAGE);
	insSet ~= new RorInstruction(0x76, 2, 6, AddrMode.ZPAGEX);
	insSet ~= new RorInstruction(0x6E, 3, 6, AddrMode.ABSOLUTE);
	insSet ~= new RorInstruction(0x7E, 3, 7, AddrMode.ABSX);
	insSet ~= new RtiInstruction(0x40, 1, 6, AddrMode.SNONE);
	insSet ~= new RtsInstruction(0x60, 1, 6, AddrMode.SNONE);
	insSet ~= new SbcInstruction(0xE9, 2, 2, AddrMode.IMMEDIATE);
	insSet ~= new SbcInstruction(0xE5, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new SbcInstruction(0xF5, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new SbcInstruction(0xED, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new SbcInstruction(0xFD, 3, 4, AddrMode.ABSX);
	insSet ~= new SbcInstruction(0xF9, 3, 4, AddrMode.ABSY);
	insSet ~= new SbcInstruction(0xE1, 2, 6, AddrMode.INDX);
	insSet ~= new SbcInstruction(0xF1, 2, 5, AddrMode.INDY);
	insSet ~= new SecInstruction(0x38, 1, 2, AddrMode.SNONE);
	insSet ~= new SedInstruction(0xF8, 1, 2, AddrMode.SNONE);
	insSet ~= new SeiInstruction(0x78, 1, 2, AddrMode.SNONE);
	insSet ~= new StaInstruction(0x85, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new StaInstruction(0x95, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new StaInstruction(0x8D, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new StaInstruction(0x9D, 3, 4, AddrMode.ABSX);
	insSet ~= new StaInstruction(0x99, 3, 4, AddrMode.ABSY);
	insSet ~= new StaInstruction(0x81, 2, 6, AddrMode.INDX);
	insSet ~= new StaInstruction(0x91, 2, 5, AddrMode.INDY);
	insSet ~= new StxInstruction(0x86, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new StxInstruction(0x96, 2, 4, AddrMode.ZPAGEY);
	insSet ~= new StxInstruction(0x8E, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new StyInstruction(0x84, 2, 3, AddrMode.ZEROPAGE);
	insSet ~= new StyInstruction(0x94, 2, 4, AddrMode.ZPAGEX);
	insSet ~= new StyInstruction(0x8C, 3, 4, AddrMode.ABSOLUTE);
	insSet ~= new TaxInstruction(0xAA, 1, 2, AddrMode.SNONE);
	insSet ~= new TayInstruction(0xA8, 1, 2, AddrMode.SNONE);
	insSet ~= new TsxInstruction(0xBA, 1, 2, AddrMode.SNONE);
	insSet ~= new TxaInstruction(0x8A, 1, 2, AddrMode.SNONE);
	insSet ~= new TxsInstruction(0x9A, 1, 2, AddrMode.SNONE);
	insSet ~= new TyaInstruction(0x98, 1, 2, AddrMode.SNONE);

	return insSet;
}

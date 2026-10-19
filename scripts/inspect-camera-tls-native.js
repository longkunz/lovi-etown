// Focused disassembly of native entries recovered from ELF relocation table.
const m=Process.getModuleByName('libflutter.so');
for(const [name,offset] of [['filter-error-region',0x979a80]]){
 let p=m.base.add(offset),rows=[];
 for(let i=0;i<500;i++){
  const ins=Instruction.parse(p);rows.push({offset:p.sub(m.base).toString(),asm:ins.toString()});p=ins.next;
  if(ins.mnemonic==='ret')break;
 }
 console.log(JSON.stringify({kind:'native-disassembly',module:m.name,entry:name,offset:'0x'+offset.toString(16),rows}));
}

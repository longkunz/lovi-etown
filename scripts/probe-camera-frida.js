// Read-only module inventory; does not change certificate validation.
for (const m of Process.enumerateModules()) {
  if (/flutter|ssl|app\.so|cronet/i.test(m.name)) {
    console.log(JSON.stringify({module:m.name,base:m.base.toString(),size:m.size,exports:m.enumerateExports().filter(e=>/SSL_(read|write)|send|recv/.test(e.name)).map(e=>({name:e.name,address:e.address.toString()}))}));
  }
}

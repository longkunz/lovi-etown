const m=Process.getModuleByName('libflutter.so');
console.log(JSON.stringify({kind:'imports',rows:m.enumerateImports().filter(e=>/SSL|ssl|send|recv|connect/.test(e.name)).map(e=>({name:e.name,address:e.address?e.address.toString():null}))}));
console.log(JSON.stringify({kind:'symbols',rows:m.enumerateSymbols().filter(e=>/SSL_(read|write)|ssl_log|keylog/.test(e.name)).map(e=>({name:e.name,address:e.address.toString()}))}));

import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import { createDecipheriv, randomUUID } from 'node:crypto';
import { pipeline } from 'node:stream/promises';

const MAGIC=Buffer.from('QUALIDADE_BACKUP_AESGCM_V1\n','ascii');
const [encryptedFile,keyFile,outputFile]=process.argv.slice(2);
if(!encryptedFile||!keyFile||!outputFile){
  console.error('Usage: node scripts/decrypt-database-backup.mjs <backup.dump.aes> <private-key.json> <restored.dump>');
  process.exit(1);
}
let key,temporary;
try{
  const record=JSON.parse(await fsp.readFile(keyFile,'utf8'));
  if(record.format!=='QUALIDADE_BACKUP_AESGCM_V1'||record.encryptedFile!==path.basename(encryptedFile))throw Error('Incompatible key file.');
  key=Buffer.from(record.keyBase64,'base64');if(key.length!==32)throw Error('Invalid key length.');
  const handle=await fsp.open(encryptedFile,'r');let header,tag,size;
  try{
    size=(await handle.stat()).size;
    if(size<=MAGIC.length+12+16)throw Error('Truncated backup.');
    header=Buffer.alloc(MAGIC.length+12);tag=Buffer.alloc(16);
    await handle.read(header,0,header.length,0);await handle.read(tag,0,tag.length,size-tag.length);
  }finally{await handle.close();}
  if(!header.subarray(0,MAGIC.length).equals(MAGIC))throw Error('Unknown backup format.');
  const decipher=createDecipheriv('aes-256-gcm',key,header.subarray(MAGIC.length));
  decipher.setAAD(header);decipher.setAuthTag(tag);
  temporary=path.join(path.dirname(path.resolve(outputFile)),`.qualidade-restore-${randomUUID()}.partial`);
  await pipeline(fs.createReadStream(encryptedFile,{start:header.length,end:size-17}),decipher,fs.createWriteStream(temporary,{flags:'wx',mode:0o600}));
  // Publish plaintext only after GCM authentication succeeds; never overwrite a file.
  await fsp.copyFile(temporary,outputFile,fs.constants.COPYFILE_EXCL);
  console.log('Backup decrypted and authenticated successfully.');
}catch{
  console.error('Restore preparation failed. Check the matching key, backup integrity, output permissions and that the output file does not already exist.');
  process.exitCode=1;
}finally{
  if(key)key.fill(0);
  if(temporary)await fsp.unlink(temporary).catch(()=>{});
}

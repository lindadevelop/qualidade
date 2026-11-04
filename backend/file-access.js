// File ownership is recorded separately from the content hash, which can be shared by companies.
const fs=require('node:fs/promises'),path=require('node:path');
const directory=path.join(__dirname,'data','file-access');
async function identity(req){const r=await fetch('http://127.0.0.1:3002/auth/v1/user',{headers:{Authorization:req.headers.authorization||''},signal:AbortSignal.timeout(5000)});if(!r.ok)return null;const user=await r.json();if(!user.app_metadata)return null;
 const selected=req.headers['x-organization-id'];if(selected){if(!/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(selected))return null;if(!user.app_metadata.is_super_admin&&selected!==user.app_metadata.organization_id)return null;user.app_metadata.organization_id=selected}return user}
async function claimFile(file,user){const name=path.basename(file);if(!/^[a-f0-9]{64}\.pdf$/.test(name))return;const org=user.app_metadata.organization_id;if(!org)return;await fs.mkdir(path.join(directory,name),{recursive:true});await fs.writeFile(path.join(directory,name,org),user.id,{flag:'a'})}
async function canReadFile(file,user){const name=path.basename(file);if(!/^[a-f0-9]{64}\.pdf$/.test(name))return false;if(user.app_metadata.is_super_admin)return true;const org=user.app_metadata.organization_id;
 try{await fs.access(path.join(directory,name,org));return true}catch{}
 return false;
}
module.exports={identity,claimFile,canReadFile};

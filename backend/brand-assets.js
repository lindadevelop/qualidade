const zlib=require('node:zlib');
function inspectPng(content,kind){
 const fail=message=>{throw Object.assign(new Error(message),{status:400})};
 if(typeof content!=='string'||content.length>2800000||!/^[A-Za-z0-9+/]+={0,2}$/.test(content))fail('O ficheiro deve ser uma imagem PNG até 2 MB.');
 const data=Buffer.from(content,'base64');if(data.length>2*1024*1024||data.length<45||!data.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10])))fail('Formato inválido. Usa uma imagem PNG, preferencialmente transparente.');
 let width,height,ended=false,parts=[];for(let offset=8;offset+12<=data.length;){const size=data.readUInt32BE(offset),type=data.toString('ascii',offset+4,offset+8);if(offset+12+size>data.length)fail('Imagem incompleta.');if(offset===8&&type!=='IHDR')fail('Imagem PNG inválida.');if(type==='IHDR'){if(size!==13||width)fail('Imagem PNG inválida.');width=data.readUInt32BE(offset+8);height=data.readUInt32BE(offset+12);if(!width||!height||width>4096||height>4096||width*height>16777216)fail('A imagem deve ter entre 1 e 4096 píxeis de largura e altura.');}if(type==='IDAT')parts.push(data.subarray(offset+8,offset+8+size));if(type==='IEND'){ended=true;break}offset+=size+12}
 if(!ended||!parts.length)fail('Imagem PNG incompleta.');try{zlib.inflateSync(Buffer.concat(parts),{maxOutputLength:140000000})}catch{fail('Não foi possível ler a imagem. Exporta novamente em PNG.')}
 if(kind==='favicon'&&(width!==height||width>512))fail('O favicon deve ser quadrado e ter no máximo 512 × 512 píxeis.');
 return {width,height,mime_type:'image/png',content_base64:data.toString('base64')};
}
async function saveBrandAsset(c,actor,org,id,p){
 if(!['logo','icon','favicon'].includes(p.kind))throw Object.assign(new Error('Tipo de imagem inválido.'),{status:400});
 const kit=(await c.query('select * from brand_kits where id=$1 and organization_id=$2 for update',[id,org])).rows[0];if(!kit)throw Object.assign(new Error('Guarda primeiro a identidade visual desta empresa.'),{status:404});
 if(p.expected_asset_id!==(kit[p.kind+'_asset_id']||null))throw Object.assign(new Error('Esta imagem mudou. Recarrega antes de substituir.'),{status:409});
 const image=inspectPng(p.content_base64,p.kind);const asset=(await c.query('insert into brand_assets(organization_id,brand_kit_id,kind,mime_type,content_base64,width,height,created_by) values($1,$2,$3,$4,$5,$6,$7,$8) returning id,kind,width,height',[org,id,p.kind,image.mime_type,image.content_base64,image.width,image.height,actor.id])).rows[0];
 await c.query(`update brand_kits set ${p.kind}_asset_id=$2,updated_at=clock_timestamp() where id=$1`,[id,asset.id]);await c.query('insert into platform_admin_history(organization_id,entity_type,entity_id,action,before_data,after_data,actor_id) values($1,$2,$3,$4,$5,$6,$7)',[org,'brand_kits',id,'asset_replace',{asset_id:kit[p.kind+'_asset_id']},{...asset},actor.id]);return asset;
}
module.exports={inspectPng,saveBrandAsset};

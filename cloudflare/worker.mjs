const maxBytes = 3 * 1024 * 1024;
const objectPath = /^\/photos\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\/(recipe|avatar)\/([0-9a-f]{64})$/;

export function imageType(bytes) {
  if (bytes.length < 12) return null;
  if ([137,80,78,71,13,10,26,10].every((n,i)=>bytes[i]===n)) return 'image/png';
  if (bytes[0]===255 && bytes[1]===216 && bytes[2]===255) return 'image/jpeg';
  const tag = (i) => String.fromCharCode(...bytes.subarray(i,i+4));
  return tag(0)==='RIFF' && tag(8)==='WEBP' ? 'image/webp' : null;
}

export default { async fetch(request, env) {
  const url = new URL(request.url);
  const upload = request.method==='POST' && /^\/photos\/(avatar|recipe)$/.test(url.pathname);
  const path = objectPath.exec(url.pathname);
  if (!upload && !(request.method==='GET' && path)) return new Response(null,{status:404});
  const authorization = request.headers.get('Authorization') || '';
  if (!authorization.startsWith('Bearer ')) return new Response(null,{status:401});
  const headers = {authorization, apikey: env.SUPABASE_KEY};
  const auth = await fetch(`${env.SUPABASE_URL}/auth/v1/user`, {headers});
  if (!auth.ok) return new Response(null,{status:auth.status===401||auth.status===403?401:503});
  const {id} = await auth.json();
  if (!id) return new Response(null,{status:401});
  if (upload) {
    const size = Number(request.headers.get('Content-Length'));
    if (!Number.isInteger(size) || size<12 || size>maxBytes) return new Response(null,{status:413});
    const bytes = new Uint8Array(await request.arrayBuffer());
    const mime = imageType(bytes);
    if (!mime || bytes.length!==size) return new Response(null,{status:415});
    const digest = await crypto.subtle.digest('SHA-256',bytes);
    const hash = [...new Uint8Array(digest)].map(n=>n.toString(16).padStart(2,'0')).join('');
    const key = `${id}/${url.pathname.split('/').pop()}/${hash}`;
    if (!await env.PHOTOS.head(key)) {
      const existing = await env.PHOTOS.list({prefix:id+'/',limit:100});
      if (existing.objects.length>=100) return new Response('Photo limit reached',{status:429});
      await env.PHOTOS.put(key,bytes,{httpMetadata:{contentType:mime}});
    }
    return Response.json({image:'r2:'+key});
  }
  const key = url.pathname.slice('/photos/'.length);
  if (path[1]!==id) {
    const lookup = new URL(env.SUPABASE_URL+'/rest/v1/community_recipes');
    lookup.searchParams.set('select','recipe_id');
    lookup.searchParams.set('owner_id','eq.'+path[1]);
    lookup.searchParams.set(path[2]==='avatar'?'recipe->>authorAvatar':'recipe->>image','eq.r2:'+key);
    lookup.searchParams.set('limit','1');
    const allowed = await fetch(lookup,{headers});
    if (!allowed.ok) return new Response(null,{status:503});
    if (!(await allowed.json()).length) return new Response(null,{status:404});
  }
  const object = await env.PHOTOS.get(key);
  if (!object) return new Response(null,{status:404});
  return new Response(object.body,{headers:{'Content-Type':object.httpMetadata.contentType,'Cache-Control':'private, no-store','X-Content-Type-Options':'nosniff'}});
}};

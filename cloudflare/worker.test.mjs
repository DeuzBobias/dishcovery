import test from 'node:test';
import assert from 'node:assert/strict';
import worker from './worker.mjs';

test('owner photos stay private until referenced by a community post', async () => {
  const owner = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  const reader = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  const objects = new Map();
  const env = {SUPABASE_URL:'https://backend.example',SUPABASE_KEY:'test',PHOTOS:{
    head: async key=>objects.get(key), list:async()=>({objects:[]}),
    put:async(key,body,options)=>objects.set(key,{body,...options}), get:async key=>objects.get(key),
  }};
  const originalFetch = globalThis.fetch;
  let shared = false;
  globalThis.fetch = async (url, options) => {
    if (String(url).endsWith('/auth/v1/user')) {
      const id = options.headers.authorization==='Bearer owner'? owner : reader;
      return Response.json({id});
    }
    assert.equal(new URL(url).searchParams.get('owner_id'), 'eq.'+owner);
    assert.match(new URL(url).searchParams.get('recipe->>image'), /^eq\.r2:/);
    return Response.json(shared?[{recipe_id:'dinner'}]:[]);
  };
  try {
    const data = new Uint8Array([137,80,78,71,13,10,26,10,0,0,0,0]);
    const upload = body=>new Request('https://worker.example/photos/recipe',{method:'POST',headers:{Authorization:'Bearer owner','Content-Length':String(body.length)},body});
    assert.equal((await worker.fetch(upload(new Uint8Array(12)),env)).status,415);
    const first = await worker.fetch(upload(data),env);
    assert.equal(first.status,200);
    const {image} = await first.json();
    assert.equal((await (await worker.fetch(upload(data),env)).json()).image,image);
    assert.equal(objects.size,1);
    const url='https://worker.example/photos/'+image.slice(3);
    const get=who=>worker.fetch(new Request(url,{headers:{Authorization:'Bearer '+who}}),env);
    assert.equal((await worker.fetch(new Request(url),env)).status,401);
    assert.equal((await get('reader')).status,404);
    assert.equal((await get('owner')).status,200);
    shared=true;
    assert.deepEqual(new Uint8Array(await (await get('reader')).arrayBuffer()),data);
  } finally { globalThis.fetch=originalFetch; }
});

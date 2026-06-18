# Yahoo 行情代理部署说明

这个代理给 App 提供**含盘前盘后**的美股涨跌幅（大陆直连不到的数据）。
代理要架在一个**既能访问 Yahoo、又能被大陆访问**的地方。

代理代码：[`yahoo-quote-proxy.js`](yahoo-quote-proxy.js)

接口：`GET /?symbols=NVDA,AAPL,QQQ,SPY,CNY=X`
返回：`{"NVDA":1.22,"AAPL":0.54,"QQQ":1.69,"SPY":0.84,"CNY=X":-0.02}`（含盘前盘后的涨跌幅 %）

---

## 方案 A：Cloudflare Workers（最快，先试这个）

1. 注册/登录 https://dash.cloudflare.com → 左侧 **Workers & Pages** → **Create** → **Create Worker**
2. 起个名字 → **Deploy** → 点 **Edit code**
3. 把 [`yahoo-quote-proxy.js`](yahoo-quote-proxy.js) 全部内容粘进去，覆盖默认代码 → **Deploy**
4. 得到地址 `https://你的名字.你的账号.workers.dev`
5. 浏览器打开 `https://你的名字.xxx.workers.dev/?symbols=NVDA,QQQ` 测试，应返回 JSON
6. **把这个地址发给我**，我填进 App 并测试

⚠️ `*.workers.dev` 在大陆有时较慢/不稳。如果你爸手机上打不开，换方案 B，或在 Cloudflare 给 Worker **绑一个自己的域名**（Workers → 你的 Worker → Settings → Domains & Routes）。

---

## 方案 B：Deno Deploy（备选，同样免费）

1. 登录 https://dash.deno.com → **New Project** → **Playground**
2. 粘贴 `yahoo-quote-proxy.js` 的内容，但把**最后两行**改成启用 Deno：
   ```js
   // export default { fetch: handle };   // 注释掉这行
   Deno.serve(handle);                    // 启用这行
   ```
3. **Save & Deploy** → 得到 `https://xxx.deno.dev`
4. 测试 `?symbols=NVDA,QQQ`，把地址发我

---

## 方案 C：香港/海外 serverless（大陆最稳，稍麻烦）

腾讯云 SCF / 阿里云 FC 选**香港**地域 + API 网关触发器，Node 运行时，
把 `handle` 包成对应的入口函数即可。香港地域能翻墙访问 Yahoo，又对大陆访问优化好。
需要的话告诉我用哪家，我给你改好入口代码。

---

## 部署后

把代理地址发我，我会：
1. 填进 App 的 `FundDataService.proxyBase`
2. 用你的代理实测盘前盘后（NVDA/QQQ 应显示盘前涨跌，而非昨收）
3. 验证通过后打正式包

> 代理只读公开行情、无密钥、无个人数据，纯转发 Yahoo 公开接口。

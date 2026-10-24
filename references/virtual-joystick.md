# 虚拟摇杆（Virtual Joystick）—— Lite Wearable 完整模板

> 2026-10-17 收录。来源：社区摇杆实现，按本工程实测约束修正后收录。
> 适用：全屏 `<stack>` + 触摸三事件 + 定时步进的任意「手指控制位移」场景
> （虚拟摇杆 / 拖拽 / 画板 / 自定义手势盘）。

---

## 〇、收录前修正了哪些坑（⚠️ 原始代码直接用会挂）

| # | 原代码写法 | 问题 | 修正 |
|---|---|---|---|
| 1 | `on:touchstart="stickStart"` | **lite 事件必须裸名**，`on:xxx` 前缀编译报错 / 不触发 | `touchstart="stickStart"` |
| 2 | `touchY(e)` 只有注释没实现 | 复制即缺函数 | 补全，与 `touchX` 同构 |
| 3 | `this.stickActive / stickOriginX / moveDX …` 直接往 `this` 挂未声明字段 | 绑定层不认、易与 data 混淆 | 全部改成**模块级变量**，`this` 上只留要绑定的字段 |
| 4 | `this.px += this.moveDX`，但 `px` 没声明 | data 里没有就别绑 | 位置状态也放模块级，只把 `pLeft/pTop`（字符串）写回 data |
| 5 | 定时器只在 `stopStick` 清 | 页面被切走时定时器还活着，会继续改 data | `onHide / onDestroy` 都要清；再加代数守卫防旧回调 |

---

## 一、事件坐标兜底链

不同 SDK / 设备的触摸事件字段不一样，按顺序取，**一个链吃遍所有版本**：

```js
function touchX(e) {
    var t = (e && e.touches && e.touches.length) ? e.touches[0] : e;
    if (!t) { return 0; }
    if (t.x !== undefined) { return t.x; }
    if (t.localX !== undefined) { return t.localX; }
    return t.pageX || t.clientX || t.globalX || 0;
}

function touchY(e) {
    var t = (e && e.touches && e.touches.length) ? e.touches[0] : e;
    if (!t) { return 0; }
    if (t.y !== undefined) { return t.y; }
    if (t.localY !== undefined) { return t.localY; }
    return t.pageY || t.clientY || t.globalY || 0;
}
```

⚠️ 摇杆（或被拖动元素）必须铺满全屏或与触摸目标同坐标系：
- 若监听在**全屏根节点**上，`globalX/globalY` 与 `left/top` 同坐标系，直接可用；
- 若监听在**局部节点**上，`globalX` 要减去该节点在页面里的偏移，否则摇杆会跳位。

---

## 二、HML（模板）

事件用**裸名**；摇杆挂在与触摸同级的 `<stack>` 里，用子节点 `left/top` 定位
（stack 子节点天然绝对定位，lite 唯一可靠的定位方式）：

```html
<stack class="screen" touchstart="stickStart" touchmove="stickMove"
       touchend="stickEnd" touchcancel="stickEnd">
    <image class="player" src="/common/p/s20.png"
           style="left: {{pLeft}}px; top: {{pTop}}px;"></image>

    <stack class="joy" if="{{stickVisible}}"
           style="left: {{stickBaseX}}px; top: {{stickBaseY}}px;">
        <image class="joy-base" src="/common/u/jbase.png"></image>
        <image class="joy-knob" src="/common/u/knob.png"
               style="left: {{stickKnobX}}px; top: {{stickKnobY}}px;"></image>
    </stack>
</stack>
```

要点：
- 摇杆 `if` 挂在**最后一个子节点**上（`if=false` 的兄弟链会把后面的节点一起吞掉，放最后最稳）；
- `knob.png` 放在 `joy` 这层 stack 里，`left/top` 是相对底座图原点的偏移；
- 底座图尺寸 = `STICK_HALF * 2`。

---

## 三、CSS（关键尺寸）

```css
.screen { width: 100%; height: 100%; }
.joy     { width: 96px;  height: 96px; }
.joy-base { width: 96px; height: 96px; }
.joy-knob { width: 40px; height: 40px; }
.player  { width: 48px; height: 48px; }
```

---

## 四、JS（完整可抄）

```js
/* ---- 常量 ---- */
var STICK_HALF = 48;    /* 底座图 96px 的一半：让底座以手指为中心 */
var KNOB_HOME = 28;     /* 摇杆头在底座里的居中位置 = (96-40)/2 */
var STICK_TRAVEL = 30;  /* 摇杆头最多偏离中心多少像素 */
var STICK_MIN = 5;      /* 死区：偏移小于它就不动 */
var STEP_MAX = 8;       /* 推到底时每一步走多少像素 */
var MOVE_MS = 90;       /* 每 90ms 走一步 */

/* ---- 模块级状态（不要往 data 里塞） ---- */
var moveTimer = null;   /* 步进定时器 */
var stickOn = 0;        /* 手指是否按着 */
var originX = 0, originY = 0;
var moveDX = 0, moveDY = 0;
var px = 0, py = 0;     /* 玩家逻辑坐标 */
var gen = 0;            /* 页面代数：切走后旧定时器回调直接作废 */

export default {
    data: {
        stickVisible: false,
        stickBaseX: '0px', stickBaseY: '0px',
        stickKnobX: KNOB_HOME + 'px', stickKnobY: KNOB_HOME + 'px',
        pLeft: '0px', pTop: '0px'
    },

    onInit: function () {
        gen = 0;
        px = 0; py = 0;
    },

    stickStart: function (e) {
        var tx = touchX(e), ty = touchY(e);
        stickOn = 1;
        originX = tx;
        originY = ty;
        moveDX = 0; moveDY = 0;
        var self = this;
        var myGen = gen;
        /* 底座以手指为中心 */
        this.stickBaseX = Math.round(tx - STICK_HALF) + 'px';
        this.stickBaseY = Math.round(ty - STICK_HALF) + 'px';
        this.stickKnobX = KNOB_HOME + 'px';
        this.stickKnobY = KNOB_HOME + 'px';
        this.stickVisible = true;
        if (moveTimer) { clearInterval(moveTimer); }
        moveTimer = setInterval(function () {
            if (myGen !== gen) { clearInterval(moveTimer); moveTimer = null; return; }
            self.movementTick();
        }, MOVE_MS);
    },

    stickMove: function (e) {
        if (!stickOn) { return; }
        var ox = touchX(e) - originX;   /* 手指相对按下点的偏移 */
        var oy = touchY(e) - originY;
        var dist = Math.sqrt(ox * ox + oy * oy);
        if (dist > STICK_TRAVEL) {      /* 超出范围按比例拉回圆内 */
            ox = Math.round(ox * STICK_TRAVEL / dist);
            oy = Math.round(oy * STICK_TRAVEL / dist);
        }
        this.stickKnobX = (KNOB_HOME + ox) + 'px';
        this.stickKnobY = (KNOB_HOME + oy) + 'px';
        /* 偏移换算成每步位移，死区内为 0 */
        moveDX = Math.abs(ox) < STICK_MIN ? 0 : Math.round(ox * STEP_MAX / STICK_TRAVEL);
        moveDY = Math.abs(oy) < STICK_MIN ? 0 : Math.round(oy * STEP_MAX / STICK_TRAVEL);
    },

    stickEnd: function () { this.stopStick(); },

    stopStick: function () {
        stickOn = 0;
        moveDX = 0; moveDY = 0;
        this.stickVisible = false;
        if (moveTimer) { clearInterval(moveTimer); moveTimer = null; }
    },

    movementTick: function () {
        if (!stickOn) { return; }
        /* 这里可以先做碰撞/边界检查再落位 */
        px += moveDX;
        py += moveDY;
        this.pLeft = Math.round(px) + 'px';
        this.pTop = Math.round(py) + 'px';
    },

    onHide: function () {
        gen++;
        this.stopStick();
    },

    onDestroy: function () {
        gen++;
        this.stopStick();
    }
};
```

---

## 五、实现要点（为什么这么写）

| 设计 | 理由 |
|---|---|
| **内部状态全用模块级变量** | 绑定层只认 data；把 `stickActive/origin/moveDX` 这类纯逻辑量放 data 里，既浪费 data 字段，又容易被渲染管线意外刷新 |
| **写回 data 的都是「带 px 的字符串」** | `left/top` 绑定要带单位；数值不带单位时部分版本不生效 |
| **定时器步进而非 touchmove 里直接移动** | touchmove 触发频率不可控；定时器把「手指输入」和「实际位移」解耦， MOVE_MS 就是移动频率上限 |
| **代数守卫（gen）** | 页面切走时只 `clearInterval` 不够——已排队的回调还会执行一次并改 data，导致「切页后角色自己走一步」。回调里比对 `gen` 直接作废 |
| **死区 STICK_MIN** | 手指微抖不产生位移，否则角色永远在爬 |
| **STICK_TRAVEL 拉回圆内** | 手指划出底座范围时摇杆头贴边，位移取最大值，不会跳变 |
| **`if` 而不是 `show`** | `show=false` 仍会构建节点并可能抢触摸；摇杆隐藏后不该再吃事件 |

---

## 六、常见坑

1. **`on:touchstart` 编译报错 / 不触发** —— lite 事件必须是裸名。
2. **模拟器里 touchmove 不来** —— 先确认监听节点铺满全屏；局部小节点上的 touchmove 各 SDK 行为不一，必要时把监听提到根节点、用坐标算。
3. **切页后角色自己走** —— 没清定时器 / 没做代数守卫。
4. **摇杆跳位** —— 监听节点与摇杆不同坐标系（见 §一 的警告）。
5. **`left/top` 不生效** —— 必须是 `<stack>` 的直接子节点；lite 无 `position` 属性，不要写。
6. **手指划出屏幕** —— `touchcancel` 也要绑到 `stickEnd`，否则摇杆卡在按住状态。

---

## 七、衍生变体

- **拖拽物体**：不要 base/knob，把玩家坐标直接设为 `touch - 抓取偏移`；
- **画板 / 轨迹**：touchmove 里把点推入数组，HML 用多个小节点画（lite 无 canvas 绘制回调）；
- **多指**：`e.touches` 按下标区分，lite 真机最多稳定支持 2 指，别按 5 指设计。

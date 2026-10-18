// Input records intent only; update() acts on it. Touch: floating joystick on the
// left, action buttons on the right. Desktop: keyboard + hold mouse to aim.
export function createInput(hud, hooks) {
  const el = hud.el;
  const keys = new Set();
  const input = {
    mx: 0, my: 0, jumpPressed: false, jumpHeld: false, dashPressed: false,
    bowDown: false, bowHeld: false, bowReleased: false, aimSource: "drag",
    dragX: 0, dragY: 0, dragLen: 0, pointerX: 0, pointerY: 0, aimWX: 0, aimWY: 0,
    switchPressed: false, upPressed: false, mapPressed: false, joyX: 0, joyY: 0, joyActive: false,
  };
  const listeners = [];
  const on = (target, type, fn, opts) => {
    target.addEventListener(type, fn, opts);
    listeners.push(() => target.removeEventListener(type, fn, opts));
  };
  let gestured = false;
  const gesture = () => {
    if (!gestured) {
      gestured = true;
      hooks.onFirstGesture?.();
    }
  };

  // Show touch controls once a touch happens (or on coarse-pointer devices).
  const setTouch = (v) => el.root.classList.toggle("touch", v);
  setTouch(window.matchMedia?.("(pointer: coarse)").matches ?? false);
  on(window, "pointerdown", (e) => {
    if (e.pointerType === "touch" || e.pointerType === "pen") setTouch(true);
    gesture();
  }, { capture: true });
  on(window, "keydown", gesture, { capture: true });

  // ---- Joystick (floating inside its zone)
  let joyId = null;
  let joyCx = 0;
  let joyCy = 0;
  const joyRadius = () => el.joy.getBoundingClientRect().width * 0.42;
  on(el.joyZone, "pointerdown", (e) => {
    if (joyId !== null) return;
    e.preventDefault();
    joyId = e.pointerId;
    el.joyZone.setPointerCapture(e.pointerId);
    const zr = el.joyZone.getBoundingClientRect();
    const jr = el.joy.getBoundingClientRect();
    const half = jr.width / 2;
    const cx = Math.max(zr.left + half, Math.min(zr.right - half, e.clientX));
    const cy = Math.max(zr.top + half, Math.min(zr.bottom - half, e.clientY));
    joyCx = cx;
    joyCy = cy;
    el.joy.style.left = `${cx - zr.left - half}px`;
    el.joy.style.top = `${cy - zr.top - half}px`;
    el.joy.style.bottom = "auto";
    el.joy.classList.add("active");
    moveJoy(e);
  });
  const moveJoy = (e) => {
    const r = joyRadius();
    let dx = e.clientX - joyCx;
    let dy = e.clientY - joyCy;
    const d = Math.hypot(dx, dy);
    if (d > r) {
      dx = (dx / d) * r;
      dy = (dy / d) * r;
    }
    el.knob.style.transform = `translate(${dx}px, ${dy}px)`;
    input.joyX = dx / r;
    input.joyY = dy / r;
    input.joyActive = true;
  };
  on(el.joyZone, "pointermove", (e) => {
    if (e.pointerId === joyId) moveJoy(e);
  });
  const endJoy = (e) => {
    if (e.pointerId !== joyId) return;
    joyId = null;
    input.joyX = 0;
    input.joyY = 0;
    input.joyActive = false;
    el.knob.style.transform = "";
    el.joy.style.left = "";
    el.joy.style.top = "";
    el.joy.style.bottom = "";
    el.joy.classList.remove("active");
  };
  on(el.joyZone, "pointerup", endJoy);
  on(el.joyZone, "pointercancel", endJoy);

  // ---- Buttons
  const press = (btn, down, up) => {
    on(btn, "pointerdown", (e) => {
      e.preventDefault();
      btn.setPointerCapture(e.pointerId);
      btn.classList.add("down");
      down(e);
    });
    const end = (e) => {
      btn.classList.remove("down");
      up?.(e);
    };
    on(btn, "pointerup", end);
    on(btn, "pointercancel", end);
  };
  press(el.jump, () => {
    input.jumpPressed = true;
    input.jumpHeld = true;
  }, () => {
    input.jumpHeld = false;
  });
  press(el.dash, () => {
    input.dashPressed = true;
  });
  press(el.swap, () => {
    input.switchPressed = true;
  });
  press(el.skill, () => {
    input.skillPressed = true;
  });
  let bowId = null;
  let bowSX = 0;
  let bowSY = 0;
  press(el.bow, (e) => {
    bowId = e.pointerId;
    bowSX = e.clientX;
    bowSY = e.clientY;
    input.bowDown = true;
    input.bowHeld = true;
    input.aimSource = "drag";
    input.dragX = 0;
    input.dragY = 0;
    input.dragLen = 0;
  }, (e) => {
    if (e.pointerId !== bowId) return;
    bowId = null;
    input.bowHeld = false;
    input.bowReleased = true;
  });
  on(el.bow, "pointermove", (e) => {
    if (e.pointerId !== bowId) return;
    input.dragX = e.clientX - bowSX;
    input.dragY = e.clientY - bowSY;
    input.dragLen = Math.hypot(input.dragX, input.dragY);
  });

  // ---- Mouse aiming on the playfield
  on(el.canvas, "pointerdown", (e) => {
    if (e.target.closest("button, .overlay, .controls")) return;
    if (e.pointerType !== "mouse" || e.button !== 0) return;
    e.preventDefault();
    el.canvas.setPointerCapture(e.pointerId);
    input.bowDown = true;
    input.bowHeld = true;
    input.aimSource = "pointer";
    setPointer(e);
  });
  const setPointer = (e) => {
    const r = el.canvas.getBoundingClientRect();
    input.pointerX = e.clientX - r.left;
    input.pointerY = e.clientY - r.top;
  };
  on(el.canvas, "pointermove", (e) => {
    if (e.pointerType === "mouse") setPointer(e);
  });
  on(el.canvas, "pointerup", (e) => {
    if (e.pointerType !== "mouse" || input.aimSource !== "pointer" || !input.bowHeld) return;
    input.bowHeld = false;
    input.bowReleased = true;
  });
  on(el.canvas, "contextmenu", (e) => e.preventDefault());

  // ---- Keyboard
  const KEYMAP = {
    ArrowLeft: "left", KeyA: "left", ArrowRight: "right", KeyD: "right",
    ArrowUp: "up", KeyW: "up", ArrowDown: "down", KeyS: "down",
    Space: "jump", KeyK: "jump", ShiftLeft: "dash", ShiftRight: "dash", KeyL: "dash",
    KeyJ: "bow", KeyQ: "swap", KeyE: "swap", KeyM: "map", KeyR: "skill",
  };
  on(window, "keydown", (e) => {
    const a = KEYMAP[e.code];
    if (!a) return;
    if (e.target instanceof HTMLElement && e.target.closest("input, textarea")) return;
    e.preventDefault();
    if (e.repeat) return;
    keys.add(a);
    if (a === "jump") {
      input.jumpPressed = true;
      input.jumpHeld = true;
    } else if (a === "dash") input.dashPressed = true;
    else if (a === "swap") input.switchPressed = true;
    else if (a === "map") input.mapPressed = true;
    else if (a === "skill") input.skillPressed = true;
    else if (a === "up") input.upPressed = true;
    else if (a === "bow") {
      input.bowDown = true;
      input.bowHeld = true;
      input.aimSource = "key";
    }
  });
  on(window, "keyup", (e) => {
    const a = KEYMAP[e.code];
    if (!a) return;
    keys.delete(a);
    if (a === "jump") input.jumpHeld = false;
    if (a === "bow" && input.aimSource === "key" && input.bowHeld) {
      input.bowHeld = false;
      input.bowReleased = true;
    }
  });
  function reset() {
    keys.clear();
    input.jumpHeld = false;
    input.bowHeld = false;
    input.joyX = input.joyY = 0;
    input.joyActive = false;
    joyId = bowId = null;
    el.knob.style.transform = "";
    el.joy.style.left = el.joy.style.top = el.joy.style.bottom = "";
    el.joy.classList.remove("active");
    el.root.querySelectorAll(".down").forEach(btn => btn.classList.remove("down"));
    clearEdges();
  }
  on(window, "blur", reset);

  function sample() {
    const kx = (keys.has("right") ? 1 : 0) - (keys.has("left") ? 1 : 0);
    const ky = (keys.has("down") ? 1 : 0) - (keys.has("up") ? 1 : 0);
    input.mx = input.joyActive ? input.joyX : kx;
    input.my = input.joyActive ? input.joyY : ky;
    if (input.joyActive && Math.abs(input.mx) < 0.22) input.mx = 0;
    return input;
  }

  function clearEdges() {
    input.jumpPressed = false;
    input.dashPressed = false;
    input.bowDown = false;
    input.bowReleased = false;
    input.switchPressed = false;
    input.upPressed = false;
    input.mapPressed = false;
    input.skillPressed = false;
  }

  return {
    input,
    sample,
    clearEdges,
    reset,
    destroy() {
      listeners.forEach((off) => off());
    },
  };
}

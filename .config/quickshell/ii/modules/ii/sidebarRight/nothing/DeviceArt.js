.pragma library

// Name rules take priority over the BlueZ icon. Put specific overrides first.
const names = [
    [/buds|airpods|earbuds|freebuds|freepods|ear\s?\(\d+\)/i, "earbuds"],
    [/speaker|soundbar|boombox/i, "speaker"]
];
const icons = [
    [/audio-(headset|headphones)|head(phone|set)/i, "headphones"],
    [/audio-(card|speaker)|speaker|audio-handsfree/i, "speaker"],
    [/phone/i, "phone"],
    [/computer|laptop/i, "laptop"],
    [/keyboard/i, "keyboard"],
    [/mouse/i, "mouse"],
    [/gaming|gamepad|controller|joystick/i, "controller"]
];

function glyph(name, icon) {
    return names.find(([pattern]) => pattern.test(name))?.[1]
        ?? icons.find(([pattern]) => pattern.test(icon))?.[1] ?? "device";
}

function part(name) {
    const match = name.toLowerCase().match(/^(.*?)[\s_([-]+(left|right|case)[)\]]?$/);
    return match ? { base: match[1].trim(), side: match[2] } : { base: name.toLowerCase().trim(), side: "" };
}

function partsFor(selected, devices) {
    const base = part(selected.name).base;
    const matching = [];
    for (const side of ["left", "right", "case"]) {
        const device = devices.find(candidate => {
            const key = part(candidate.name);
            return (candidate.connected || candidate.paired) && candidate.batteryAvailable
                && key.base === base && key.side === side;
        });
        if (device)
            matching.push({ side, value: device.battery });
    }
    return matching;
}

.pragma library

// Size is [columns, rows]. The ordered list fills empty cells left to right.
const tiles = [
    { type: "bluetooth", size: [2, 2], shape: "card" },
    { type: "wifi", size: [2, 1], shape: "pill" },
    { type: "volume", size: [2, 1], shape: "card" },
    { type: "brightness", size: [2, 1], shape: "card" },
    { type: "media", size: [2, 2], shape: "card" },
    { type: "clock", size: [1, 1], shape: "square" },
    { type: "battery", size: [1, 1], shape: "square" },
    { type: "mic", size: [1, 1], shape: "circle" },
    { type: "dnd", size: [1, 1], shape: "circle" },
    { type: "night", size: [1, 1], shape: "circle" },
    { type: "airplane", size: [1, 1], shape: "circle" },
    { type: "record", size: [1, 1], shape: "circle" },
    { type: "screenshot", size: [1, 1], shape: "circle" },
    { type: "caffeine", size: [1, 1], shape: "circle" },
    { type: "profile", size: [1, 1], shape: "square" },
    { type: "cpu", size: [1, 1], shape: "square" },
    { type: "ram", size: [1, 1], shape: "square" },
    { type: "playback", size: [1, 1], shape: "square" },
    { type: "scheme", size: [1, 1], shape: "circle" },
    { type: "notifications", size: [2, 1], shape: "pill" },
    { type: "settings", size: [1, 1], shape: "circle" },
    { type: "session", size: [1, 1], shape: "circle" },
    { type: "lock", size: [1, 1], shape: "circle" },
    { type: "sleep", size: [1, 1], shape: "circle" },
    { type: "reboot", size: [1, 1], shape: "circle" },
    { type: "power", size: [1, 1], shape: "circle" }
];

function pack(definitions, columns) {
    const occupied = [];
    const items = [];
    let rowCount = 0;
    for (const tile of definitions) {
        const wide = Math.min(columns, Math.max(1, Math.floor(tile.size[0]) || 1));
        const tall = Math.max(1, Math.floor(tile.size[1]) || 1);
        let row = 0;
        let col = 0;
        for (; ; row++) {
            for (col = 0; col <= columns - wide; col++) {
                let free = true;
                for (let y = row; free && y < row + tall; y++) {
                    for (let x = col; free && x < col + wide; x++)
                        free = !occupied[y]?.[x];
                }
                if (free)
                    break;
            }
            if (col <= columns - wide)
                break;
        }
        for (let y = row; y < row + tall; y++) {
            if (!occupied[y]) occupied[y] = [];
            for (let x = col; x < col + wide; x++)
                occupied[y][x] = true;
        }
        items.push({ type: tile.type, shape: tile.shape, row, col, wide, tall });
        rowCount = Math.max(rowCount, row + tall);
    }
    return { items, rowCount };
}

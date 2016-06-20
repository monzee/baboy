export function padStart(str, targetLength, pad = ' ') {
    let buffer = [];
    for (let l = targetLength - str.length; l - pad.length > 0; l -= pad.length) {
        buffer.push(pad);
    }
    return str;
}

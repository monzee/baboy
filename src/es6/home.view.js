import * as util from './util';

export function tell(message) {
    console.log(util.padStart(message, 10));
}

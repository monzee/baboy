import {bind} from './home.presenter';
import * as view from './home.view';

window.run = (config) => {
    bind(view);
}

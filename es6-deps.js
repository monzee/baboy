#!/usr/bin/env node
'use strict';

const detective = require('detective-es6');
const fs = require('fs');
const getOpt = require('node-getopt').create([
    ['t', 'target=NAME+', 'the Makefile target(s)'],
    ['', 'no-target', 'print the dependencies only'],
    ['r', 'root=PATH', 'path to prefix to the arguments'],
    ['b', 'base=PATH', 'base path for determining the stem'],
    ['g', 'graft=PATH', 'replace the base paths of the dependencies'],
    ['', 'no-append',
        'do not include the real dependency paths. Only applicable when grafting.'],
    ['h', 'help', "you really need it."],
]).bindHelp();

function transitiveDependencies(root) {
    function walk(src, seen, recur) {
        seen[src.location] = true;
        src.dependencies().forEach(dep => {
            let next = src.to(dep.endsWith('.js') ? dep : `${dep}.js`);
            if (next.exists() && !seen[next.location]) {
                walk(next, seen, true);
            }
        });
        recur || delete seen[src.location];
        return Object.keys(seen);
    }

    let s = new Source(root);
    return {source: s, deps: walk(s, {})};
}

function join(prefix, rest) {
    let dir = prefix.replace(/\/+$/, '');
    let name = rest.replace(/^\/+/, '');
    return `${dir}/${name}`;
}

function quote(s) {
    return s.replace(/[\s\\]/g, '\\$1');
}

class Source {
    constructor(location) {
        location = Source.canonical(location);
        let lastSlash = location.lastIndexOf('/');
        let lastDot = location.lastIndexOf('.');
        this.location = location;
        this.path = location.substring(0, lastSlash);
        this.name = location.substring(lastSlash);
        if (lastDot > lastSlash) {
            this.baseName = location.substring(0, lastDot);
            this.suffix = location.substring(lastDot);
        } else {
            this.baseName = location;
            this.suffix = '';
        }
    }

    dependencies() {
        return detective(fs.readFileSync(this.location, 'utf8'));
    }

    to(path) {
        if (path.startsWith('/')) {
            return new Source(path);
        } else if (path.startsWith('.')) {
            return new Source(`${this.path}/${path}`);
        } else {
            return new External(this, path);
        }
    }

    exists() {
        return fs.existsSync(this.location);
    }

    static canonical(path) {
        for (let done = false; !done;) {
            done = true;
            path = path.replace(/[^\/]+\/\.\.\//, () => {
                done = false;
                return '';
            });
        }
        return path.replace(/\.\//g, '');
    }
}

class External {
    constructor(from, name) {
        this.dependent = from;
        this.location = name;
    }

    exists() {
        return false;
    }

    dependencies() {
        return [];
    }

    to(path) {
        return this.dependent.to(path);
    }
}

let cli = getOpt.parseSystem();
if (!cli.options.target && !cli.options['no-target']) {
    getOpt.showHelp();
    console.log('make target is required!');
    process.exit(1);
} else {
    let root = cli.options.root || '.';
    let target = cli.options.target;
    let base = Source.canonical(cli.options.base || './');
    let graft = cli.options.graft;
    let allDeps = cli.argv.map(s => transitiveDependencies(join(root, s)).deps)
    let replace = graft && !!cli.options['no-append'];
    let depSet = allDeps.reduce((set, xs) => {
        xs.forEach(d => {
            if (!replace) {
                set[d] = true;
            }
            if (graft) {
                let stem = d.startsWith(base) ? d.substring(base.length) : d;
                set[Source.canonical(join(graft, stem))] = true;
            }
        });
        return set;
    }, {});
    if (cli.options['no-target']) {
        console.log(depSet);
    } else {
        let deps = Object.keys(depSet).map(quote).join(' ');
        target.forEach(t => console.log(`${t}: ${deps}`));
    }
}

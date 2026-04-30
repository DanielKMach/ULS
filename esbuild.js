const esbuild = require('esbuild');
const { existsSync: exists } = require('node:fs');
const { copyFile, mkdir } = require('node:fs/promises')

const production = process.argv.includes('--production');
const watch = process.argv.includes('--watch');

async function main() {
    const ctx = await esbuild.context({
        entryPoints: ['out/extension.js'],
        bundle: true,
        format: 'cjs',
        minify: production,
        sourcemap: !production,
        sourcesContent: false,
        platform: 'node',
        outfile: 'dist/extension.js',
        tsconfig: 'tsconfig.json',
        external: ['vscode'],
        logLevel: 'warning',
        plugins: [
            /* add to the end of plugins array */
            esbuildProblemMatcherPlugin
        ]
    });

    if (watch) {
        await ctx.watch();
    } else {
        await ctx.rebuild();
        await ctx.dispose();
    }

    const binDir = 'bin';
    const binaries = ['uls-windows.exe', 'uls-macos', 'uls-linux'];

    if (!exists(`./dist/${binDir}`)) await mkdir(`./dist/${binDir}`);
    await Promise.all(binaries.map(uls => {
        if (!production && !exists(`./zig-out/bin/${uls}`)) return;
        return copyFile(`./zig-out/bin/${uls}`, `./dist/${binDir}/${uls}`);
    }));
}

/**
 * @type {import('esbuild').Plugin}
 */
const esbuildProblemMatcherPlugin = {
    name: 'esbuild-problem-matcher',

    setup(build) {
        build.onStart(() => {
            console.log('[watch] build started');
        });
        build.onEnd(result => {
            result.errors.forEach(({ text, location }) => {
                console.error(`✘ [ERROR] ${text}`);
                if (location == null) return;
                console.error(`    ${location.file}:${location.line}:${location.column}:`);
            });
            console.log('[watch] build finished');
        });
    }
};

main().catch(e => {
    console.error(e);
    process.exit(1);
});

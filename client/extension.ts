import { spawn } from 'node:child_process';
import { platform } from 'node:process';
import * as vscode from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	StreamInfo,
} from 'vscode-languageclient/node';

const id = "usrl";

let client: LanguageClient;

export function activate(context: vscode.ExtensionContext) {
	const serverOpts = () => {
		const path = (platform == 'win32')
			? `${__dirname}\\bin\\uls.exe`
			: `${__dirname}/bin/uls`;

		const server = spawn(path);
		const stream: StreamInfo = {
			reader: server.stdout,
			writer: server.stdin,
		};

		client.outputChannel.appendLine("\r\n=== CONNECTED TO ULS ===");
		server.stderr.on('data', chunk => {
			client.outputChannel.append(chunk.toString());
		})

		return Promise.resolve(stream);
	}

	const clientOpts: LanguageClientOptions = {
		outputChannelName: "USRL Language Server",
		outputChannel: vscode.window.createOutputChannel("USRL Language Server"),
		documentSelector: [{ language: 'usrl' }],
	};

	client = new LanguageClient(
		id,
		'USRL Language Server',
		serverOpts,
		clientOpts
	);

	client.start();
}

export function deactivate(): Thenable<void> | undefined {
	if (!client) return;
	return client.stop();
}

vscode.commands.registerCommand(`${id}.runQuery`, query => {
	const term = vscode.window.terminals.find(t => t.name == "USRL")
		|| vscode.window.createTerminal('USRL');

	const exe = vscode.workspace.getConfiguration(id).get<string>("preferredExecutable") || 'usrl';

	switch (term.state.shell) {
		case 'pwsh':
			term.sendText(escapePS(exe, query), true);
			break;

		case 'cmd':
			term.sendText(escapeCmd(exe, query), true);
			break;

		case 'bash':
		case 'gitbash':
		default:
			term.sendText(escapeBash(exe, query), true);
			break;
	}
	term.show();
});

vscode.commands.registerCommand(`${id}.openManual`, () => {
	vscode.env.openExternal(vscode.Uri.parse("https://danielkmach.github.io/USRL"));
})

vscode.commands.registerCommand(`${id}.restartLanguageServer`, () => {
	client.restart();
})

function escapePS(...args: string[]): string {
	const escape = (arg: string) => {
		if (/^[a-zA-Z0-9_\-./]+$/.test(arg)) return arg;
		return '"' + arg.replaceAll('$', '`$').replaceAll('"', '`"') + '"';
	}

	return args
		.map((v, i) => i == 0 ? '&' + escape(v) : escape(v))
		.join(' ');
}

function escapeCmd(...args: string[]): string {
	const escape = (arg: string) => {
		if (/^[a-zA-Z0-9_\-./]+$/.test(arg)) return arg;
		return '"' + arg.replaceAll('"', '""').replaceAll('\n', '\n ^') + '"';
	}

	return args.map(escape).join(' ');
}

function escapeBash(...args: string[]): string {
	const escape = (arg: string) => {
		if (/^[a-zA-Z0-9_\-./]+$/.test(arg)) return arg;
		return '"' + arg.replaceAll('"', '\\"').replaceAll('$', '\\$') + '"';
	}

	return args.map(escape).join(' ');
}
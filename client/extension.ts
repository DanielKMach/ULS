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
	const terminal = vscode.window.terminals.find(t => t.name == "USRL")
		|| vscode.window.createTerminal('USRL');

	const exe = vscode.workspace.getConfiguration(id).get<string>("preferredExecutable") || 'usrl';

	terminal.sendText(`${escapeExePS(exe)} ${escapeArgPS(query)}`, true);
	terminal.show();
});

vscode.commands.registerCommand(`${id}.openManual`, () => {
	vscode.env.openExternal(vscode.Uri.parse("https://danielkmach.github.io/USRL"));
})

vscode.commands.registerCommand(`${id}.restartLanguageServer`, () => {
	client.restart();
})

function escapeArgPS(arg: string) {
	return '"' + arg.replaceAll('$', '`$').replaceAll('"', '`"') + '"';
}

function escapeExePS(exe: string) {
	if (exe.includes(' ')) return `&${escapeArgPS(exe)}`;
	return exe;
}
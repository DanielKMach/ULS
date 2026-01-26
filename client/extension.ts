import { spawn } from 'node:child_process';
import { platform } from 'node:process';
import * as vscode from 'vscode';

import {
	LanguageClient,
	LanguageClientOptions,
	StreamInfo,
} from 'vscode-languageclient/node';

const id = "usrlLanguageServer";
const run_query_command = `${id}.runQuery`;

let client: LanguageClient;
let output: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext) {
	const serverOpts = () => {
		const path = (platform == 'win32')
			? `${__dirname}\\bin\\ulsp.exe`
			: `${__dirname}/bin/ulsp`;

		const server = spawn(path);
		const stream: StreamInfo = {
			reader: server.stdout,
			writer: server.stdin,
		};

		output = output || vscode.window.createOutputChannel("USRL Language Server", id);
		output.appendLine("\r\n=== CONNECTED TO ULS ===");
		server.stderr.on('data', chunk => {
			output.append(chunk.toString());
		})

		return Promise.resolve(stream);
	}

	const clientOpts: LanguageClientOptions = {
		documentSelector: [{ scheme: 'file', pattern: '**/*.usrl' }],
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

vscode.commands.registerCommand(run_query_command, query => {
	const terminal = vscode.window.terminals.find(t => t.name == "USRL")
		|| vscode.window.createTerminal('USRL');

	terminal.show();
	terminal.sendText(`usrl "${query}"`, true);
});
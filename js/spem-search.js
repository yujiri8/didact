import {LitElement, html, css} from 'lit-element';
import {unsafeHTML} from 'lit-html/directives/unsafe-html.js';

import './input-list.js';
import * as util from './util.js';
import {styles} from './css.js';

customElements.define('spem-search', class extends LitElement {
	static get properties() {
		return {
			admin: {type: Boolean, attribute: false},
			tags: {type: Array, attribute: false},
			words: {type: Array, attribute: false},
		}
	}
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host { display: block; }
		td, th {
			padding: 3px;
		}
		.tag {
			white-space: nowrap;
		}
		`];
	}
	constructor() {
		super();
		this.words = [];
		this.tags = [];
		this.admin = util.readCookie('admin');
	}
	render() {
		return html`
		<div style="display:flex; flex-wrap:wrap">
			<div style="flex:1; min-width:18em">
				<div style="display:flex; flex-wrap:wrap">
					<div>
						<div title="Enter multiple space-separated words to find them all.">
							<label for="word">Spem Word</label>
							<input id="word" type="text" autocapitalize="off" @keydown="${this.searchOnEnter}">
						</div>
						<div title="Searches for Spem words needed to express the equivalent, even if the translation isn't direct. This means the parts of speech won't always match.">
							<label for="translation">Translation</label>
							<input id="translation" type="text" autocapitalize="off" @keydown="${this.searchOnEnter}">
						</div>
						<div title="Search for words with a given string in the Notes field. Case-insensitive.">
							<label for="notes">Notes</label>
							<input id="notes" type="text" autocapitalize="off" @keydown="${this.searchOnEnter}">
						</div>
						<label for="notes-regex">Notes (PCRE)</label>
						<input id="notes-regex" type="text" autocapitalize="off" @keydown="${this.searchOnEnter}">
					</div>
					<div>
						<label for="tags">Tags</label>
						<input-list id="tags" class="indent" type="select" .options="${this.tags}"
								@keydown="${this.searchOnEnter}">
						</input-list>
					</div>
				</div>
				<br>
				<button @click="${this.search}">Search</button>
				<p>
				Pressing Enter while typing in a text field or Esc will submit the search.
				</p>
			</div>
			${this.admin? html`
				<fieldset style="flex:1; min-width:18em">
					<legend>Admin</legend>
					<div style="display:flex; flex-wrap:wrap">
						<div>
							<label for="admin-word">θɑr</label>
							<input id="admin-word" type="text" autocapitalize="off">
							<br>
							<label for="admin-meaning">kel nɑy θen nɑ</label>
							<input id="admin-meaning" type="text" autocapitalize="off">
						</div>
						<div>
							<label for="admin-translations">kel θetsu nɑy av nɑ</label>
							<input-list id="admin-translations" class="indent"></input-list>
						</div>
						<div>
							<label for="admin-tags">Tags</label>
							<input-list id="admin-tags" class="indent" .options="${this.tags}"></input-list>
						</div>
					</div>
					<label for="admin-notes">Notes</label>
					<textarea id="admin-notes" @input="${util.autogrow}" style="display:block; width:100%"></textarea>
					<button @click="${this.addWord}">jini</button>
					<button @click="${this.changeWord}">yɪŋ</button>
					<button @click="${() => this.fetchWord(this.shadowRoot.getElementById('admin-word').value)}">gi kei</button>
				</fieldset>
			`:''}
		</div>
		<p id="result-count"></p>
		<div style="overflow-x:auto">
		<table>
			<thead><tr>
			<th>Word</th>
			<th>Meaning</th>
			<th>Translations</th>
			<th>Notes</th>
			<th>Tags</th>
			${this.admin? html`<th>Actions</th>`:''}
			</tr></thead>
			<tbody id="results">
			${this.words.map(word => html`
				<tr class="word">
				<td><spem>${word.name}</spem></td>
				<td style="min-width: ${Math.min(20, word.meaning.length/2)}em">${word.meaning}</td>
				<td>${word.translations.join(', ')}</td>
				<td style="text-align: left; min-width: ${Math.min(30, word.notes.length/2)}em">
					${unsafeHTML(word.notes)}</td>
				<td>${unsafeHTML(word.tags.map(t => `<span class="tag">${t}</span>`)
					.join(', '))}</td>
				${this.admin? html`<td>
					<button @click="${() => this.deleteWord(word.name)}">Delete</button>
					<button @click="${() => this.fetchWord(word.name)}">Fetch</button>
				</td>`:''}
				</tr>
			`)}
			</tbody>
		</table>
		</div>
		<p>
		Sometimes, even when a word has an English word that's an exact parallel and is perfectly clear, I try to
		fill the Meaning field with a formal definition anyway, just as a philosophical exercise.
		</p>
		`;
	}
	async connectedCallback() {
		super.connectedCallback();
		// Esc anywhere should search.
		addEventListener('keyup', e => {
			if (e.key === 'Escape') this.search();
		});
		this.tags = await util.api('GET', 'spem/tags');
	}
	searchOnEnter(e) {
		if (e.key === 'Enter') this.search();
	}
	async firstUpdated() {
		this.pageloadSearch();
	}
	async pageloadSearch() {
		const args = util.parseQuery(location.search);
		const possibleArgs = ['word', 'translation', 'tag', 'notes', 'notes_regex'];
		if (!possibleArgs.some(p => p in args)) return;
		this.shadowRoot.getElementById('word').value = args.word || '';
		this.shadowRoot.getElementById('translation').value = args.translation || '';
		this.shadowRoot.getElementById('notes').value = args.notes || '';
		this.shadowRoot.getElementById('notes-regex').value = args.notes_regex || '';
		this.shadowRoot.getElementById('tags').setData(
			args.tag? (args.tag instanceof Array? args.tag : [args.tag]) : []);
		this.search();
	}
	async search() {
		// Gather data.
		const query = {
			word: this.shadowRoot.getElementById('word').value || undefined,
			translation: this.shadowRoot.getElementById('translation').value || undefined,
			notes: this.shadowRoot.getElementById('notes').value || undefined,
			notes_regex: this.shadowRoot.getElementById('notes-regex').value || undefined,
			tag: this.shadowRoot.getElementById('tags').getData(),
		}
		this.words = await util.api('GET', 'spem/words', query);
		this.shadowRoot.getElementById('result-count').innerText = `${this.words.length} results found`;
	}
	async deleteWord(word) {
		await util.api('DELETE', `spem/words/${word}`, undefined);
		util.showToast('success', `${word} deleted`);
	}
	async fetchWord(word) {
		const newWord = (await util.api('GET', 'spem/words', {word: word, raw: true}))[0];
		// Fill in data.
		this.shadowRoot.getElementById('admin-word').value = newWord.name;
		this.shadowRoot.getElementById('admin-meaning').value = newWord.meaning;
		this.shadowRoot.getElementById('admin-notes').value = newWord.notes;
		util.autogrow({target: this.shadowRoot.getElementById('admin-notes')});
		this.shadowRoot.getElementById('admin-translations').setData(newWord.translations);
		this.shadowRoot.getElementById('admin-tags').setData(newWord.tags);
	}
	// A helper to format the entries of the admin widgets as a Word object.
	getAdminData() {
		return {
			name: this.shadowRoot.getElementById('admin-word').value,
			meaning: this.shadowRoot.getElementById('admin-meaning').value,
			notes: this.shadowRoot.getElementById('admin-notes').value,
			translations: this.shadowRoot.getElementById('admin-translations').getData(),
			tags: this.shadowRoot.getElementById('admin-tags').getData(),
		};
	}
	async addWord() {
		const word = this.getAdminData();
		await util.api('POST', 'spem/words', undefined, word);
		util.showToast('success', `${word.name} added`);
	}
	async changeWord() {
		const word = this.getAdminData();
		await util.api('PUT', 'spem/words', undefined, word);
		util.showToast('success', `${word.name} changed`);
	}
});

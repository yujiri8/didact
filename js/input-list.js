import {LitElement, html, css} from 'lit-element';

import {styles} from './css.js';

customElements.define('input-list', class extends LitElement {
	static get properties() {
		return {
			options: {type: Array, attribute: false},
			type: {type: String},
		}
	}
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host { display: block; }
		`];
	}
	constructor() {
		super();
		this.options = [];
		this.inputs = [];
	}
	render() {
		return html`
		<!-- This is here so the input-list will keep its width if there are no inputs. -->
		<div style="visibility:hidden; height:0">
			<input id="hide">
			<button>x</button>
		</div>
		<div id="inputs"></div>
		<button @click="${this.addInput}">+</button>
		`;
	}
	addInput() {
		const container = this.shadowRoot.getElementById('inputs');
		const elem = document.createElement('div');
		elem.innerHTML = `
			${this.type != 'select'? `
				<input type="text" autocapitalize="off" list="options">
				<datalist id="options">
			`:`
				<select>
			`}
			${this.options.map(o => `
				<option value="${o}">${o}</option>
			`)}
			${this.type != 'select'? `
				</datalist>
			`:`
				<select>
			`}
			<button onclick="this.parentNode.remove()">x</button>
		`;
		container.appendChild(elem);
		// Return it so the caller has the option of using it.
		return elem;
	}
	getData() {
		return Array.from(this.shadowRoot.querySelectorAll('input:not(#hide), select')).map(
			elem => elem.value);
	}
	setData(items) {
		// Clear the field.
		Array.from(this.shadowRoot.querySelectorAll('input:not(#hide), select')).map(
			elem => elem.parentNode.remove());
		// Add items with the new data.
		for (let item of items) {
			const newInput = this.addInput();
			newInput.querySelector('input, select').value = item;
		}
	}
});

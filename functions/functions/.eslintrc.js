module.exports = {
	root: true,
	env: {
		es6: true,
		node: true,
	},
	extends: [
		"eslint:recommended",
		"google",
	],
	rules: {
		"quotes": ["error", "double"],
		"max-len": ["error", {"code": 200}],
		"no-tabs": 0,
		"indent": [
			"error",
			"tab",
		],
	},
	parserOptions: {
		ecmaVersion: 8,
	},
};

#!/bin/sh
# This is a pre-build script that generates templates.cr. It's used to get
# around the limitations of Crystal macros so adding templates doesn't
# require modifying actual source code.

# First write the header.
cat > src/scripts/templates.cr << EOF
# This file is generated by gen-templates.sh.

alias TemplateArg = String | Bool | Array(String) | Time

TEMPLATES = {} of String => Proc(Hash(String, TemplateArg), String)

EOF

# Now write a line for each template.
for file in `ls content-templates`; do
	echo "TEMPLATES[\"`basename $file .ecr`\"] =" \
			"->(args : Hash(String, TemplateArg)) { ECR.render \"content-templates/$file\" }" \
		>> src/scripts/templates.cr
done

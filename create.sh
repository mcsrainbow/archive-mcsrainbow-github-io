#!/bin/bash
# Create posts step by step using the correct format

echo -n "Input the Post Title: "
read post_title
if [ -z "$post_title" ];then
  echo "ERROR: Post Title cannot be empty"
  exit 2
fi
echo "INFO: Post Title is: ${post_title}"

echo -n "Input the Post Description: "
read post_description
if [ -z "$post_description" ];then
  echo "INFO: Post Description is empty"
fi

echo -n "Input the Post Category Number {'1':'读书笔记','2':'技能矩阵','3':'生活感悟']}: "
read post_category_num
if [ "$post_category_num" == "1" ];then
  post_category="读书笔记"
  post_category_en="Notes"
elif [ "$post_category_num" == "2" ];then
  post_category="技能矩阵"
  post_category_en="Skills"
elif [ "$post_category_num" == "3" ];then
  post_category="生活感悟"
  post_category_en="Thinking"
else
  echo "ERROR: The Post Category Number must be in 1-3"
  exit 2
fi
echo "INFO: Post Category is: ${post_category}"

echo -n "Input the Post Tags, eg: 领导力,ITIL: "
read post_tags
if [ -z "$post_tags" ];then
  echo "INFO: Post Tags is empty"
else
  post_tags_formatted=$(echo $post_tags | sed s/,/\",\"/g)
fi
echo "INFO: Post Tags is: \"${post_tags_formatted}\" "

echo -n "Enable featured image? [yes|no] "
read featured_image
if [ "$featured_image" == "yes" ];then
  echo "INFO: Featured image is enabled"
fi

echo -n "Enable the table of the contents? [yes|no] "
read toc_enabled
if [ "$toc_enabled" == "yes" ];then
  echo "INFO: The table of contents is enabled"
fi

echo -n "Rename the Post Directory name string? By default it is Post Category: "
read post_dir_namestr
if [ -z "$post_dir_namestr" ];then
  echo "INFO: Post Directory name string is empty"
  post_dir_namestr=$post_category_en
fi

echo -n "Enable English? [yes|no] "
read enable_english
if [ "$enable_english" == "yes" ];then
  echo "INFO: English is enabled"
fi

post_date_str=$(date +%Y-%m-%dT%H:%M:%S+08:00)
post_date=$(date +%Y%m%d-%H%M)
post_dir="${post_date}-${post_dir_namestr}"

mkdir content/posts/${post_dir}
cat > content/posts/${post_dir}/index.zh-cn.md <<EOF
---
title: "${post_title}"
date: ${post_date_str}
author: "郭冬"
description: "${post_description}"
categories: ["${post_category}"]
tags: ["${post_tags_formatted}"]
EOF

if [ "$featured_image" == "yes" ];then
  cat >> content/posts/${post_dir}/index.zh-cn.md <<EOF
resources:
- name: "featured-image"
  src: "featured-image.jpeg"

EOF
fi

if [ "$toc_enabled" == "no" ];then
  cat >> content/posts/${post_dir}/index.zh-cn.md <<EOF
toc: false
EOF
fi

cat >> content/posts/${post_dir}/index.zh-cn.md <<EOF
lightgallery: true
---

${post_description}

<!--more-->

EOF

if [ "$enable_english" == "yes" ];then
  cat > content/posts/${post_dir}/index.en.md <<EOF
---
title: "${post_title}"
date: ${post_date_str}
author: "Dong Guo | Damon"
description: "${post_description}"
categories: ["${post_category_en}"]
tags: ["${post_tags_formatted}"]
EOF

  if [ "$featured_image" == "yes" ];then
    cat >> content/posts/${post_dir}/index.en.md <<EOF
resources:
- name: "featured-image"
  src: "featured-image.jpeg"

EOF
  fi

  if [ "$toc_enabled" == "no" ];then
    cat >> content/posts/${post_dir}/index.en.md <<EOF
toc: false
EOF
  fi

  cat >> content/posts/${post_dir}/index.en.md <<EOF
lightgallery: true
---

${post_description}

<!--more-->

EOF
fi

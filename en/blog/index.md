---
layout: Blog
title: Blog
excerpt: Hello World
---
<div class="bg-dark pt-5">
    <div class="container">
        <div class="row">
            <div class="col-lg-9 col-md-8 col-sm-12">
                {% assign fruits = "orange,apple,peach" | split: ',' %}
                {%- for post in fruits -%}
                <article class="card mb-4 p-4">
                    <div class="row justify-content-center">
                        <div class="text-center col-lg-4 col-md-12 d-none d-lg-block pe-2">
                            Hello
                        </div>
                    </div>
                </article>
                {%- endfor -%}
            </div>
            <aside class="col-lg-3 col-md-4 col-sm-12">
                Aside
            </aside>
        </div>
    </div>
</div>

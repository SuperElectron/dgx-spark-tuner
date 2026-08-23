https://github.com/spark-arena/eugr-recipes/blob/main/recipes/qwen3.6-35b-a3b-nvfp4.yaml

`@eugr/qwen3.6-35b-a3b-nvfp4`, pulled 2026-08-23.

`recipe.yaml` is that recipe de-rayed for a single node: no
`--distributed-executor-backend ray`, no `tensor_parallel`. The box has one
GB10, so the published `tensor_parallel: 2` cannot run here.

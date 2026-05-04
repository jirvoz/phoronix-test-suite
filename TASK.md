# Fix: PyTorch test profile crashes when called with empty arguments

## Problem

The `pts/pytorch` test profile (`pts-core` or `ob-cache/test-profiles/pts/pytorch-*`) crashes with `SyntaxError: invalid syntax` when Phoronix runs it with no arguments (empty `$1`, `$2`, `$3`).

This happens because `RunAllTestCombinations=TRUE` in batch mode generates all menu option combinations **plus a "default" run with empty arguments**. The 18 specific combinations (device × batch_size × model) all work fine, but the argumentless default run always fails.

## Root cause

The `install.sh` for the pytorch test profile creates a shell script called `pytorch` that takes 3 positional arguments: `$1` (device), `$2` (batch size), `$3` (model name). It generates inline Python code using these arguments. When called with no arguments, it produces syntactically invalid Python:

```python
from torchvision.models import    # $3 is empty → SyntaxError
model = ().to("")                  # $1 is empty  
batch_size=                        # $2 is empty → SyntaxError
```

The current `install.sh` (version 1.1.0) looks like this:

```sh
#!/bin/sh
pip install --user torch==2.2.1 torchvision==0.17.1 torchaudio==2.2.1 pytorch-benchmark==0.3.6
echo $? > ~/install-exit-status
echo "#!/bin/sh
echo \"import torch
import yaml
from torchvision.models import \$3
from pytorch_benchmark import benchmark
num_threads = torch.get_num_threads()
print(f'Benchmarking on {num_threads} threads')
model = \$3().to(\\\"\$1\\\")
sample = torch.randn(2, 3, 224, 224)  # (B, C, H, W)
results = benchmark(model, sample, num_runs=1000, print_details=True, batch_size=\$2)
print(yaml.dump(results))
\" > pytorch-benchmark.py
python3 pytorch-benchmark.py > \$LOG_FILE 2>&1
echo \$? > ~/test-exit-status" > pytorch
chmod +x pytorch
```

## What to fix

Add argument validation to the generated `pytorch` shell script so it exits gracefully when called without the required 3 arguments, rather than generating broken Python code. The script should check that `$1` (device), `$2` (batch size), and `$3` (model) are all non-empty before proceeding, and exit with a clear error message if they're missing.

The test profile files are at: `ob-cache/test-profiles/pts/pytorch-*/install.sh`

Check if there's a newer version (1.2.0+) as well — the same fix likely applies there.

## Impact

This error shows up in every single Phoronix benchmark run that includes pytorch. The composite.xml accumulates `<Result>` blocks with empty `<Arguments>` and `<Description>`, where every `<Entry>` has an error. Over 50+ historical runs, this creates noise in the results and triggers false error notifications. The actual pytorch benchmark results (all 18 specific subtests) are unaffected and work correctly.

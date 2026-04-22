#!/bin/sh
pip install --user setuptools
pip install --user torch==2.6.0 torchvision==0.21.0 torchaudio==2.6.0 pytorch-benchmark==0.3.6
echo $? > ~/install-exit-status
echo "#!/bin/sh
if [ -z \"\$1\" ] || [ -z \"\$2\" ] || [ -z \"\$3\" ]; then
	echo 'ERROR: Missing required arguments: device, batch_size, model' > \$LOG_FILE
	echo 1 > ~/test-exit-status
	exit 1
fi
echo \"import torch
import yaml
from torchvision.models import \$3
from pytorch_benchmark import benchmark
#print(torchvision.models.list_models())
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

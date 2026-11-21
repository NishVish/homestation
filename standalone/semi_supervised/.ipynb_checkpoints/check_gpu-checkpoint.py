
import torch

print("PyTorch:", torch.__version__)
print("CUDA available:", torch.cuda.is_available())

if torch.cuda.is_available():

    print("GPU:", torch.cuda.get_device_name(0))

    print(
        "VRAM:",
        round(
            torch.cuda.get_device_properties(0).total_memory
            / 1024**3,
            2
        ),
        "GB"
    )

    x = torch.randn(
        3000, 3000,
        device="cuda"
    )

    y = x @ x

    print("GPU computation successful!")
    print("Result:", y.shape)

else:
    print("CUDA NOT AVAILABLE")

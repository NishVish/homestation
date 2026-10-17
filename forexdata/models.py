from django.db import models


class MLDataset(models.Model):
    session = models.CharField(
        max_length=30,
        db_index=True
    )

    data = models.JSONField()

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    class Meta:
        db_table = "ml_dataset"

param(
    [string]$Root = "E:\robot",
    [string]$OutputDir = "E:\robot\.tmp\sport_robot_final_parts_v1",
    [string]$PreviewPath = "E:\robot\assets\designs\sport_robot_final_parts_preview_from_v4_plus_fixes_v1.png"
)

Add-Type -AssemblyName System.Drawing

$sourceCode = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

public static class RobotPartExporter
{
    static bool IsBackground(Color c)
    {
        return c.A > 0 && c.R >= 238 && c.G >= 238 && c.B >= 238;
    }

    public static void ExportPart(string sourcePath, Rectangle crop, string outputPath, int canvasW, int canvasH, double fill)
    {
        using (var src = new Bitmap(sourcePath))
        {
            Rectangle srcBounds = new Rectangle(0, 0, src.Width, src.Height);
            crop.Intersect(srcBounds);
            using (var part = src.Clone(crop, PixelFormat.Format32bppArgb))
            {
                int w = part.Width;
                int h = part.Height;
                bool[,] visited = new bool[w, h];
                Queue<Point> q = new Queue<Point>();

                Action<int,int> enqueue = (x, y) => {
                    if (x < 0 || y < 0 || x >= w || y >= h || visited[x, y]) return;
                    Color c = part.GetPixel(x, y);
                    if (!IsBackground(c)) return;
                    visited[x, y] = true;
                    q.Enqueue(new Point(x, y));
                };

                for (int x = 0; x < w; x++) { enqueue(x, 0); enqueue(x, h - 1); }
                for (int y = 0; y < h; y++) { enqueue(0, y); enqueue(w - 1, y); }

                while (q.Count > 0)
                {
                    Point p = q.Dequeue();
                    part.SetPixel(p.X, p.Y, Color.FromArgb(0, 255, 255, 255));
                    enqueue(p.X + 1, p.Y);
                    enqueue(p.X - 1, p.Y);
                    enqueue(p.X, p.Y + 1);
                    enqueue(p.X, p.Y - 1);
                }

                int[,] component = new int[w, h];
                List<int> componentSizes = new List<int>();
                componentSizes.Add(0);
                int componentId = 0;
                Queue<Point> cq = new Queue<Point>();
                for (int sy = 0; sy < h; sy++)
                {
                    for (int sx = 0; sx < w; sx++)
                    {
                        if (component[sx, sy] != 0 || part.GetPixel(sx, sy).A == 0) continue;
                        componentId++;
                        int count = 0;
                        component[sx, sy] = componentId;
                        cq.Enqueue(new Point(sx, sy));
                        while (cq.Count > 0)
                        {
                            Point p = cq.Dequeue();
                            count++;
                            int[,] dirs = new int[,] { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } };
                            for (int d = 0; d < 4; d++)
                            {
                                int nx = p.X + dirs[d, 0];
                                int ny = p.Y + dirs[d, 1];
                                if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                                if (component[nx, ny] != 0 || part.GetPixel(nx, ny).A == 0) continue;
                                component[nx, ny] = componentId;
                                cq.Enqueue(new Point(nx, ny));
                            }
                        }
                        componentSizes.Add(count);
                    }
                }

                if (componentId > 1)
                {
                    int keep = 1;
                    for (int i = 2; i < componentSizes.Count; i++)
                    {
                        if (componentSizes[i] > componentSizes[keep]) keep = i;
                    }
                    for (int y = 0; y < h; y++)
                    {
                        for (int x = 0; x < w; x++)
                        {
                            if (part.GetPixel(x, y).A != 0 && component[x, y] != keep)
                                part.SetPixel(x, y, Color.FromArgb(0, 255, 255, 255));
                        }
                    }
                }

                int minX = w, minY = h, maxX = -1, maxY = -1;
                for (int y = 0; y < h; y++)
                {
                    for (int x = 0; x < w; x++)
                    {
                        if (part.GetPixel(x, y).A == 0) continue;
                        if (x < minX) minX = x;
                        if (y < minY) minY = y;
                        if (x > maxX) maxX = x;
                        if (y > maxY) maxY = y;
                    }
                }
                if (maxX < minX || maxY < minY) throw new Exception("No foreground found in " + sourcePath);

                Rectangle fg = Rectangle.FromLTRB(minX, minY, maxX + 1, maxY + 1);
                using (var trimmed = part.Clone(fg, PixelFormat.Format32bppArgb))
                using (var canvas = new Bitmap(canvasW, canvasH, PixelFormat.Format32bppArgb))
                using (var g = Graphics.FromImage(canvas))
                {
                    g.Clear(Color.Transparent);
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.SmoothingMode = SmoothingMode.HighQuality;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    double scale = Math.Min((canvasW * fill) / trimmed.Width, (canvasH * fill) / trimmed.Height);
                    int drawW = Math.Max(1, (int)Math.Round(trimmed.Width * scale));
                    int drawH = Math.Max(1, (int)Math.Round(trimmed.Height * scale));
                    int dx = (canvasW - drawW) / 2;
                    int dy = (canvasH - drawH) / 2;
                    g.DrawImage(trimmed, new Rectangle(dx, dy, drawW, drawH));
                    Directory.CreateDirectory(Path.GetDirectoryName(outputPath));
                    canvas.Save(outputPath, ImageFormat.Png);
                }
            }
        }
    }

    public static void BuildPreview(string outputDir, string previewPath, string[] slots)
    {
        int cellW = 340, cellH = 320, cols = 4;
        int rows = (int)Math.Ceiling(slots.Length / (double)cols);
        using (var sheet = new Bitmap(cellW * cols, cellH * rows, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(sheet))
        using (var font = new Font("Arial", 18))
        using (var brush = new SolidBrush(Color.FromArgb(40, 40, 40)))
        {
            g.Clear(Color.White);
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            for (int i = 0; i < slots.Length; i++)
            {
                string slot = slots[i];
                string path = Path.Combine(outputDir, slot + ".png");
                using (var img = new Bitmap(path))
                {
                    int col = i % cols;
                    int row = i / cols;
                    Rectangle box = new Rectangle(col * cellW + 20, row * cellH + 45, cellW - 40, cellH - 65);
                    double scale = Math.Min(box.Width / (double)img.Width, box.Height / (double)img.Height);
                    int dw = (int)Math.Round(img.Width * scale);
                    int dh = (int)Math.Round(img.Height * scale);
                    int dx = box.X + (box.Width - dw) / 2;
                    int dy = box.Y + (box.Height - dh) / 2;
                    g.DrawString(slot, font, brush, col * cellW + 18, row * cellH + 12);
                    g.DrawImage(img, new Rectangle(dx, dy, dw, dh));
                }
            }
            Directory.CreateDirectory(Path.GetDirectoryName(previewPath));
            sheet.Save(previewPath, ImageFormat.Png);
        }
    }
}
"@

Add-Type -TypeDefinition $sourceCode -ReferencedAssemblies System.Drawing

$sheet = Join-Path $Root "assets\designs\sport_robot_14_side_parts_reference_no_up_black_v4_candidate.png"
$torso = Join-Path $Root "assets\designs\single_torso_waist_angle_yellow_alignment_v1.png"
$outerHand = Join-Path $Root "assets\designs\single_outer_hand_no_palmroot_strip_v1.png"

$slots = @(
    @{ Name = "head"; Source = $sheet; Crop = @(270, 15, 235, 225); Size = @(266, 259); Fill = 0.88 },
    @{ Name = "torso"; Source = $torso; Crop = @(0, 0, 1024, 1536); Size = @(248, 279); Fill = 0.96 },
    @{ Name = "outer_upper_arm"; Source = $sheet; Crop = @(150, 315, 290, 115); Size = @(305, 77); Fill = 0.96 },
    @{ Name = "inner_upper_arm"; Source = $sheet; Crop = @(470, 315, 290, 115); Size = @(305, 77); Fill = 0.96 },
    @{ Name = "outer_forearm"; Source = $sheet; Crop = @(805, 315, 300, 115); Size = @(343, 80); Fill = 0.96 },
    @{ Name = "inner_forearm"; Source = $sheet; Crop = @(1140, 315, 300, 115); Size = @(343, 80); Fill = 0.96 },
    @{ Name = "outer_hand"; Source = $outerHand; Crop = @(0, 0, 1370, 1148); Size = @(296, 163); Fill = 0.96 },
    @{ Name = "inner_hand"; Source = $sheet; Crop = @(875, 445, 230, 145); Size = @(296, 163); Fill = 0.90 },
    @{ Name = "outer_thigh"; Source = $sheet; Crop = @(270, 580, 130, 255); Size = @(78, 261); Fill = 0.96 },
    @{ Name = "inner_thigh"; Source = $sheet; Crop = @(565, 580, 120, 255); Size = @(78, 261); Fill = 0.96 },
    @{ Name = "outer_shin"; Source = $sheet; Crop = @(780, 580, 115, 255); Size = @(76, 268); Fill = 0.96 },
    @{ Name = "inner_shin"; Source = $sheet; Crop = @(1065, 580, 115, 255); Size = @(76, 268); Fill = 0.96 },
    @{ Name = "outer_foot"; Source = $sheet; Crop = @(360, 820, 380, 170); Size = @(290, 221); Fill = 0.94 },
    @{ Name = "inner_foot"; Source = $sheet; Crop = @(765, 820, 380, 170); Size = @(290, 221); Fill = 0.94 }
)

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
foreach ($slot in $slots) {
    $rect = New-Object System.Drawing.Rectangle($slot.Crop[0], $slot.Crop[1], $slot.Crop[2], $slot.Crop[3])
    $out = Join-Path $OutputDir "$($slot.Name).png"
    [RobotPartExporter]::ExportPart($slot.Source, $rect, $out, $slot.Size[0], $slot.Size[1], [double]$slot.Fill)
    Write-Host "WROTE $out"
}

Copy-Item -LiteralPath (Join-Path $Root "assets\skins\sport_robot\skin.json") -Destination (Join-Path $OutputDir "skin.json") -Force
[RobotPartExporter]::BuildPreview($OutputDir, $PreviewPath, [string[]]($slots | ForEach-Object { $_.Name }))
Write-Host "WROTE $PreviewPath"

$ErrorActionPreference = 'Stop'
$workspacePath = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$designPath = Join-Path $workspacePath 'docs/ui/stitch'
$sourceIds = @('5deb576d1dc17d7c5515ad13', '662b7f651afb9c00172dc992', '586e28a0f9fab7001111b0b3')
$jpegAssets = @($sourceIds | ForEach-Object {
    $jpegPath = Join-Path $designPath ('assets/' + $_ + '.jpg')
    'data:image/jpeg;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($jpegPath))
})

function Set-ReviewAssets([string] $markup) {
    $script:assetIndex = 0
    $markup = [regex]::Replace($markup, '(?s)<img\b[^>]*>', [Text.RegularExpressions.MatchEvaluator] {
        param($match)
        $imageTag = $match.Value
        $index = if ($imageTag -match 'id="cameraHeroFeed"|object-contain') { 0 } else { $script:assetIndex % $jpegAssets.Count }
        $script:assetIndex++
        $imageTag = [regex]::Replace($imageTag, '\s+onerror="[^"]*"', '')
        [regex]::Replace($imageTag, 'src="[^"]*"', ('src="' + $jpegAssets[$index] + '"'))
    })
    # Keep only the generated Tailwind configuration; previews must not start timers or call an upstream.
    $markup = [regex]::Replace($markup, '(?s)<script>.*?</script>', [Text.RegularExpressions.MatchEvaluator] {
        param($match)
        if ($match.Value.Contains('tailwind.config')) { $match.Value } else { '' }
    })
    $markup = [regex]::Replace($markup, '\s+onclick="[^"]*"', '')
    $markup = [regex]::Replace($markup, '(?s)<button\b[^>]*>.*?</button>', [Text.RegularExpressions.MatchEvaluator] {
        param($match)
        $button = $match.Value
        if ($button -match 'text-amber|text-yellow|data-weight="fill"' -and $button -match '>star</span>') {
            $solidStar = '<svg class="text-amber-500" width="22" height="22" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="m12 2.5 2.94 5.96 6.58.96-4.76 4.64 1.12 6.55L12 17.52l-5.88 3.09 1.12-6.55-4.76-4.64 6.58-.96Z"/></svg>'
            $button = [regex]::Replace($button, '<span[^>]*>star</span>', $solidStar)
        }
        $button
    })
    $markup.Replace('Yêu thích', 'Quan tâm')
}

$mainMarkup = Set-ReviewAssets (Get-Content -Raw (Join-Path $designPath 'camera-inline-favorites-generated.html'))
$mainMarkup = $mainMarkup.Replace('flex-1 px-4 pt-1 pb-8 flex flex-col gap-5', 'flex-1 min-h-0 overflow-y-auto px-4 pt-1 pb-8 flex flex-col gap-5')
$frameStyle = @'
<style>
html,body{margin:0;min-height:876px!important;height:876px!important;overflow:hidden}
body{align-items:center;padding:16px;box-sizing:border-box;background:#eef3f7}
main{width:390px!important;max-width:390px!important;min-height:0!important;height:844px!important;flex:0 0 390px;overflow:hidden;border:1px solid #dce4e8;border-radius:32px}
main>header,main>section{flex-shrink:0}
button,input{min-height:48px}button{touch-action:manipulation}
.liquid-glass-sheet{background:rgba(250,253,255,.82);backdrop-filter:blur(24px) saturate(180%);-webkit-backdrop-filter:blur(24px) saturate(180%);box-shadow:0 -8px 36px rgba(11,28,48,.18),inset 0 1px 0 #fff;border-top:1px solid rgba(255,255,255,.95)}
.liquid-glass-sheet button{min-width:48px}.liquid-glass-sheet img{object-fit:contain}
</style>
'@
$mainMarkup = $mainMarkup.Replace('</head>', $frameStyle + '</head>')
Set-Content (Join-Path $designPath 'camera-inline-favorites-review.html') -Value $mainMarkup -Encoding utf8

$sheetSource = Get-Content -Raw (Join-Path $designPath 'camera-sheet-open-generated.html')
$sheetMarkup = [regex]::Match($sheetSource, '(?s)<section aria-label="Chi tiết Camera Snapshot".*?</section>').Value
if ([string]::IsNullOrWhiteSpace($sheetMarkup)) { throw 'Snapshot sheet missing from generated HTML' }
$sheetMarkup = [regex]::Replace($sheetMarkup, '(?s)<!-- Contextual Quick Note on Traffic Flow -->.*?(?=</div>\s*<!-- iOS Home Bar)', '')
$sheetMarkup = [regex]::Replace($sheetMarkup, '(?s)<!-- Timestamp Overlay: Top Right -->.*?(?=<!-- Corner Refraction)', '')
$sheetMarkup = [regex]::Replace($sheetMarkup, '<span class="w-2 h-2 rounded-full bg-emerald-400[^>]*></span>', '')
$sheetMarkup = $sheetMarkup.Replace('Huỳnh Tấn Phát - Phú Thuận', 'Pasteur – Lê Thánh Tôn').Replace('Phường Phú Thuận · TTH 320', 'TP.HCM · Dữ liệu mẫu')
$sheetMarkup = $sheetMarkup.Replace('Ảnh chụp thời gian thực camera giao thông', 'Ảnh chụp camera giao thông')
$sheetMarkup = $sheetMarkup.Replace('aria-label="Chi tiết Camera Snapshot"', 'role="dialog" aria-modal="true" aria-label="Xem ảnh camera"')
$sheetMarkup = $sheetMarkup.Replace('max-h-[82%]', 'max-h-[90%]')
$sheetMarkup = $sheetMarkup.Replace('text-on-surface truncate', 'text-on-surface whitespace-normal').Replace('w-11 h-11', 'w-12 h-12').Replace('h-11 px-3.5', 'h-12 px-3')
$sheetMarkup = [regex]::Replace($sheetMarkup, '<span class="font-label-md text-label-md text-on-surface font-semibold">Đã lưu</span>', '')
$sheetMarkup = $sheetMarkup.Replace('flex items-center justify-between px-1 text-on-surface-variant', 'flex flex-col items-start gap-1 px-1 text-on-surface-variant')
$sheetMarkup = $sheetMarkup.Replace('class="w-full h-full object-cover object-center block"', 'class="w-full h-full object-contain block"')
$sheetMarkup = [regex]::Replace($sheetMarkup, '(?s)<!-- Snapshot Metadata & Source Status -->.*?(?=</div>\s*<!-- iOS Home Bar)', '')
$sheetMarkup = $sheetMarkup.Replace('<div class="relative w-full aspect-video rounded-2xl overflow-hidden bg-on-surface shadow-md border border-outline-variant/30 group">', '<button type="button" aria-label="Mở ảnh toàn màn hình; hỗ trợ xoay ngang và phóng to" class="relative block p-0 w-full aspect-video rounded-2xl overflow-hidden bg-on-surface shadow-md border border-outline-variant/30 group">')
# Match CRLF exports as well as LF exports.
$sheetMarkup = [regex]::Replace($sheetMarkup, '</div>\s*</div>\s*(?=<!-- iOS Home Bar)', '</button></div>')
$sheetMarkup = Set-ReviewAssets $sheetMarkup
$scrimMarkup = '<div class="absolute inset-0 z-50 bg-slate-900/25 backdrop-blur-[1px]" aria-hidden="true"></div>'
$sheetMarkup = $sheetMarkup.Replace('z-30 rounded-t', 'z-[60] rounded-t')
$sheetDocument = $mainMarkup.Replace('</main>', $scrimMarkup + $sheetMarkup + '</main>')
Set-Content (Join-Path $designPath 'camera-sheet-open-review.html') -Value $sheetDocument -Encoding utf8

foreach ($mode in @('camera-inline-favorites', 'camera-sheet-open')) {
    $markup = Get-Content -Raw (Join-Path $designPath ($mode + '-review.html'))
    [pscustomobject]@{
        mode = $mode
        embeddedImages = ([regex]::Matches($markup, 'src="data:image/jpeg;base64,')).Count
        hasInventedTrafficClaim = $markup.Contains('Giao thông thông thoáng') -or $markup.Contains('28 km/h')
        hasFalseCount = $markup.Contains('718 camera')
        hasUpstreamRefresh = $markup.Contains('triggerRefresh') -or $markup.Contains('const baseUrl')
        hasModal = $markup.Contains('aria-modal="true"')
    } | ConvertTo-Json -Compress
}

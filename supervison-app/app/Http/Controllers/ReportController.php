<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ReportController extends Controller
{
    public function store(Request $request)
    {
        $json = $request->getContent();
        $filename = 'reports/' . now()->format('Ymd_His') . '.json';
        Storage::put($filename, $json);

        return response()->json(['status' => 'received']);
    }
}

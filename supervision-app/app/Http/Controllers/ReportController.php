<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ReportController extends Controller {
    public function store(Request $request) {
        $json = $request->getContent();
        if(empty($json)){
            return response()->json(['error'=>'Invalid JSON'],400);

        }
         $filename='reports/' . now()->format('Ymd_His') . '.json';
         Storage::disk('local')->put($filename, $json);

        return response()->json(['status' => 'received'],200);
    }
}
